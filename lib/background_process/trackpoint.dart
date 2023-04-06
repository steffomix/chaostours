import 'dart:convert';

import 'package:chaostours/globals.dart';
import 'package:chaostours/app_loader.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/address.dart';
import 'package:chaostours/model/model_trackpoint.dart';
import 'package:chaostours/model/model_alias.dart'; // for read only
import 'package:chaostours/util.dart' as util;
import 'package:chaostours/logger.dart';
import 'package:chaostours/cache.dart';
import 'package:chaostours/app_settings.dart';
import 'package:chaostours/file_handler.dart';

enum TrackingStatus {
  none(0),
  standing(1),
  moving(2);

  final int value;
  const TrackingStatus(this.value);

  static TrackingStatus byValue(int id) {
    TrackingStatus status =
        TrackingStatus.values.firstWhere((status) => status.value == id);
    return status;
  }
}

class TrackPoint {
  final Logger logger = Logger.logger<TrackPoint>();

  static TrackPoint? _instance;
  TrackPoint._() {
    _oldStatus = _status;
    Logger.prefix = '~~';
    Logger.backgroundLogger = true;
  }
  factory TrackPoint() => _instance ??= TrackPoint._();

  /// int _nextId = 0;
  /// contains all trackpoints from current state start or stop
  final List<GPS> gpsPoints = [];
  final List<GPS> smoothGps = [];
  final List<GPS> calcGpsPoints = [];

  TrackingStatus _status = TrackingStatus.none;
  TrackingStatus _oldStatus = TrackingStatus.none;

  Future<void> startShared({required double lat, required double lon}) async {
    // cache gps
    // the time can't be too long due to this task gets killed anyway
    Globals.cacheGpsTime = const Duration(seconds: 30);

    /// create gpsPoint
    GPS gps = GPS.lastGps = GPS(lat, lon);

    // init app
    // await AppLoader.webKey(); // not needed
    //await AppLoader.loadSharedSettings();
    await Globals.loadSettings();
    //await AppSettings.loadFromShared();
    if ((FileHandler.storagePath ?? '').isEmpty) {
      logger.warn('No valid storage key, skip trackpoint');
      return;
    }
    await FileHandler().lookupStorages();

    Cache cache = Cache.instance;
    await cache.loadBackground();
    // if not yet set, do it right now
    cache.lastStatusChange ??= gps;

    /// load foreground data
    await cache.loadForeground();

    /// reset forground data as soon as possible
    /// to reduce critical window
    await cache.saveForeground(trigger: false, trackPoints: [], activeTp: '');

    /// parse status from json
    _status = cache.status;

    await ModelTrackPoint.open();

    /// update trackpoints
    try {
      for (var row in Cache.instance.trackPointData) {
        await ModelTrackPoint.update(ModelTrackPoint.toModel(row));
      }
      Cache.instance.trackPointData.clear();
    } catch (e, stk) {
      logger.error('update trackpoints: ${e.toString()}', stk);
    }

    /// clear only needed if method runs in foreground
    /// gpsPoints.clear();
    try {
      gpsPoints.add(gps);
      gpsPoints.addAll(cache.gpsPoints);

      calculateSmoothGps();

      if (cache.status == TrackingStatus.none) {
        /// app start, no status yet
        _oldStatus = _status = TrackingStatus.standing;
      }

      /// remember old status
      _oldStatus = _status;

      /// save 10 times of gpsPoints needed for one time range
      while (gpsPoints.length >
          (Globals.timeRangeTreshold.inSeconds /
                  Globals.trackPointInterval.inSeconds *
                  10)
              .round()) {
        // don't remove the very last.
        // it's required to measure durations
        gpsPoints.removeAt(gpsPoints.length - 2);
      }

      ///
      /// process trackpoint
      /// get status
      ///
      trackPoint();

      /// if nothing changed simply write data back
      if (_status != _oldStatus) {
        /// status has changed to _status.
        /// if we are now moving, we need to save the gpsPoint where
        /// standing was detected, which is the last one in the list.
        if (_status == TrackingStatus.moving) {
          await ModelAlias.open();

          /// write new entry only if no restricted alias is present
          var restricted = false;

          /// if this area is not restricted
          /// we reuse this list to update lastVisited
          List<ModelAlias> aliasList = [];
          for (ModelAlias alias
              in ModelAlias.nextAlias(gps: calcGpsPoints.first)) {
            if (alias.deleted) {
              // don't process deleted items
              continue;
            }
            aliasList.add(alias);
            if (alias.status == AliasStatus.restricted) {
              restricted = true;
            }
          }

          if (!restricted &&
              (!Globals.statusStandingRequireAlias ||
                  (Globals.statusStandingRequireAlias &&
                      aliasList.isNotEmpty))) {
            /// insert new entry
            /// don't forget to load database first
            /// create Model from where we detected status standing
            /// which is the last gpsPoints entry
            ModelTrackPoint newEntry = await createModelTrackPoint(
                gps: calcGpsPoints.first, aliasList: aliasList);
            await ModelTrackPoint.insert(newEntry);

            /// update last visited entrys in ModelAlias
            for (var item in aliasList) {
              if (!item.deleted) {
                item.lastVisited = DateTime.now();
                item.timesVisited++;
              }
            }
            await ModelAlias.write();

            logger.important(
                'Save new Trackpoint #${newEntry.id} with data: \n${newEntry.toString()}');
          } else {
            logger.important(
                'New trackpoint not saved due to app settings- or alias restrictions');
          }

          /// new status is standing
          /// remember address from detecting standing
          /// to be used in createModelTrackPoint on next status change
          if (Globals.osmLookupCondition != OsmLookup.never) {
            cache.address = (await Address(gps).lookupAddress()).toString();
          }
        } else {
          /// new status is standing
          /// remember address from detecting standing
          /// to be used in createModelTrackPoint on next status change
          if (Globals.osmLookupCondition == OsmLookup.onStatus) {
            cache.address = (await Address(gps).lookupAddress()).toString();
          }
        }

        /// status changed
        /// write only last inserted gpsPoint back
        // disabled due to causes too much pause
        //gpsPoints.clear();
        //gpsPoints.add(gps);

        /// update last status change for next sessions
        cache.lastStatusChange = gps;
      }
      if (Globals.osmLookupCondition == OsmLookup.always) {
        cache.address = (await Address(gps).lookupAddress()).toString();
      } else if (Globals.osmLookupCondition == OsmLookup.never) {
        cache.address = '';
      }
    } catch (e, stk) {
      logger.error(e.toString(), stk);
    }
    try {
      /// save status and gpsPoints for next session and foreground live tracking view
      await cache.saveBackground(
          status: _status,
          lastStatus: cache.lastStatusChange ??= gps,
          gpsPoints: gpsPoints,
          smoothGps: smoothGps,
          calcPoints: calcGpsPoints,
          lastGps: gps,
          address: cache.address);
    } catch (e, stk) {
      logger.error(e.toString(), stk);
    }
  }

  void calculateSmoothGps() {
    int smooth = Globals.gpsPointsSmoothCount;
    if (smooth < 2) {
      smoothGps.addAll(gpsPoints);
      return;
    }
    if (gpsPoints.length <= smooth) {
      return;
    }
    int index = 0;
    while (index <= gpsPoints.length - 1 - smooth) {
      double smoothLat = 0;
      double smoothLon = 0;
      for (var i = 1; i <= smooth; i++) {
        smoothLat += gpsPoints[index + i - 1].lat;
        smoothLon += gpsPoints[index + i - 1].lon;
      }
      smoothLat /= smooth;
      smoothLon /= smooth;
      GPS gps = GPS(smoothLat, smoothLon);
      if (smoothGps.isNotEmpty) {
        int m = GPS.distance(gps, smoothGps.last).round();
        int s = Globals.trackPointInterval.inSeconds;
        double ms = m / s;
        double kmh = ms * 3.6;
        if (kmh > Globals.gpsMaxSpeed) {
          continue;
        }
      }

      gps.time = gpsPoints[index].time;
      smoothGps.add(gps);
      index++;
    }
  }

  void trackPoint() {
    // get gpsPoints of globals time range
    // to measure movement
    List<GPS> gpsList = [];
    DateTime treshold = DateTime.now().subtract(Globals.timeRangeTreshold);
    bool fullTresholdRange = false;
    for (var gps in smoothGps) {
      if (gps.time.isAfter(treshold)) {
        gpsList.add(gps);
      } else {
        fullTresholdRange = true;
        break;
      }
    }
    calcGpsPoints.addAll(gpsList);

    /// status change triggered by user
    if ((_status == TrackingStatus.standing ||
            _status == TrackingStatus.none) &&
        Cache.instance.statusTriggered) {
      _status = TrackingStatus.moving;
      return;
    }

    /// gps points min count
    if (!fullTresholdRange || gpsList.length < 3) {
      return;
    }

    /// check if we started moving
    if (_status == TrackingStatus.standing || _status == TrackingStatus.none) {
      if (GPS.distance(gpsList.first, gpsList.last) >
          Globals.distanceTreshold) {
        _status = TrackingStatus.moving;
      }

      /// check if we stopped moving
    } else if (_status == TrackingStatus.moving) {
      if (GPS.distanceoverTrackList(gpsList) < Globals.distanceTreshold) {
        _status = TrackingStatus.standing;
      }
    }
  }

  Future<ModelTrackPoint> createModelTrackPoint(
      {required GPS gps, required List<ModelAlias> aliasList}) async {
    await logger.log('create new ModelTrackPoint');
    String notes = '';
    List<int> idTask = [];
    List<int> idUser = [];
    List<int> idAlias = aliasList.map((e) => e.id).toList();

    try {
      if (Cache.instance.activeTrackPoint.isEmpty) {
        logger.warn('no cached trackPoint Data found');
      } else {
        ModelTrackPoint tps =
            ModelTrackPoint.toSharedModel(Cache.instance.activeTrackPoint);
        notes = tps.notes; // user input
        idTask = tps.idTask; // user input
        idUser = tps.idUser; // user input
      }
    } catch (e, stk) {
      logger.error('load activetrackPoint cache: ${e.toString()}', stk);
    }
    ModelTrackPoint tp = ModelTrackPoint(
        gps: gps,
        trackPoints: gpsPoints.map((e) => e).toList(),
        idAlias: idAlias,
        timeStart: Cache.instance.lastStatusChange?.time ?? gps.time);
    tp.address = Cache.instance.address; // should be loaded at this point
    tp.status = _oldStatus;
    tp.timeEnd = calcGpsPoints.first.time;
    tp.idTask = idTask;
    tp.idUser = idUser;
    tp.notes = notes;
    return tp;
  }
}
