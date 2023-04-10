import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

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
import 'package:shared_preferences/shared_preferences.dart';

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
  final List<PendingGps> gpsPoints = [];
  final List<PendingGps> smoothGpsPoints = [];
  final List<PendingGps> calcGpsPoints = [];

  TrackingStatus _status = TrackingStatus.none;
  TrackingStatus _oldStatus = TrackingStatus.none;

  Future<void> startShared({required double lat, required double lon}) async {
    /// create gpsPoint
    PendingGps gps = PendingGps(lat, lon);
    GPS.lastGps = gps;
    await FileHandler.loadSettings();

    if (!(await FileHandler.dirExists(FileHandler.storagePath ?? ''))) {
      logger
          .warn('No valid storage ${FileHandler.storagePath}, skip trackpoint');
      return;
    }

    // load trackpoints
    await ModelTrackPoint.open();

    await Globals.loadSettings();
    // overwrite gps cache settings
    Globals.cacheGpsTime = const Duration(seconds: 30);

    Cache cache = Cache.instance;
    await cache.loadBackground(gps);
    // if not yet set, do it right now
    cache.lastStatusChange ??= gps;

    /// load foreground data
    await cache.loadForeground(gps);

    /// update trackpoints
    try {
      for (var row in Cache.instance.trackPointUpdates) {
        await ModelTrackPoint.update(row);
      }
      Cache.instance.trackPointUpdates.clear();
    } catch (e, stk) {
      logger.error('update trackpoints: ${e.toString()}', stk);
    }

    /// reset forground data as soon as possible
    /// to reduce critical window
    await cache.saveForeground(gps);

    /// parse status from json
    _status = cache.trackingStatus;

    /// clear only needed if method runs in foreground
    /// gpsPoints.clear();
    try {
      gpsPoints.add(gps);
      gpsPoints.addAll(cache.gpsPoints);

      calculateSmoothPoints();
      calculateCalcPoints();

      if (cache.trackingStatus == TrackingStatus.none) {
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
            cache.lastStatusChange = gps;

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
      cache.gpsPoints = gpsPoints;
      cache.calcGpsPoints = calcGpsPoints;
      cache.smoothGpsPoints = smoothGpsPoints;
      cache.lastGps = gps;
      cache.trackingStatus = _status;
      cache.recentTrackPoints = ModelTrackPoint.recentTrackPoints();
      cache.lastVisitedTrackPoints = ModelTrackPoint.lastVisited(gps);
    } catch (e, stk) {
      logger.error('load recent trackpoints: $e', stk);
    }

    try {
      /// save status and gpsPoints for next session and foreground live tracking view
      await cache.saveBackground(gps);
    } catch (e, stk) {
      logger.error('save backround finaly; $e', stk);
    }
    var inst = await SharedPreferences.getInstance();
    // make sure everything is saved
    await inst.reload();
    // wait before shutdown task
    await Future.delayed(const Duration(seconds: 1));
  }

  void calculateSmoothPoints() {
    int smooth = Globals.gpsPointsSmoothCount;
    if (smooth < 2) {
      smoothGpsPoints.addAll(gpsPoints);
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
      PendingGps gps = PendingGps(smoothLat, smoothLon);
      if (smoothGpsPoints.isNotEmpty) {
        int m = GPS.distance(gps, smoothGpsPoints.last).round();
        int s = Globals.trackPointInterval.inSeconds;
        double ms = m / s;
        double kmh = ms * 3.6;
        if (kmh > Globals.gpsMaxSpeed) {
          logger.warn('calculate smooth gps with $kmh speed');
        }
      }

      gps.time = gpsPoints[index].time;
      smoothGpsPoints.add(gps);
      index++;
    }
  }

  void calculateCalcPoints() {
    // get gpsPoints of globals time range
    // to measure movement
    calcGpsPoints.clear();
    if (smoothGpsPoints.length > 2) {
      List<PendingGps> gpsList = [];
      int tRef = smoothGpsPoints.first.time.millisecondsSinceEpoch;
      int dur = Globals.timeRangeTreshold.inMilliseconds;
      int dur2 = Globals.trackPointInterval.inMilliseconds;
      int tUntil = tRef - dur - dur2;

      bool fullTresholdRange = false;
      for (var gps in smoothGpsPoints) {
        if (gps.time.millisecondsSinceEpoch >= tUntil) {
          gpsList.add(gps);
        } else {
          fullTresholdRange = true;
          break;
        }
      }
      if (fullTresholdRange) {
        calcGpsPoints.addAll(gpsList);
      }
    }
  }

  void trackPoint() {
    /// status change triggered by user
    if ((_status == TrackingStatus.standing ||
            _status == TrackingStatus.none) &&
        Cache.instance.statusTriggered) {
      _status = TrackingStatus.moving;
      return;
    }

    /// gps calc points min count
    if (calcGpsPoints.length < 3) {
      return;
    }

    /// check if we started moving
    if (_status == TrackingStatus.standing || _status == TrackingStatus.none) {
      if (GPS.distance(calcGpsPoints.first, calcGpsPoints.last) >
          Globals.distanceTreshold) {
        _status = TrackingStatus.moving;
      }

      /// check if we stopped moving
    } else if (_status == TrackingStatus.moving) {
      if (GPS.distanceoverTrackList(calcGpsPoints) < Globals.distanceTreshold) {
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
      ModelTrackPoint tps = Cache.instance.pendingTrackPoint;
      notes = tps.notes; // user input
      idTask = tps.idTask; // user input
      idUser = tps.idUser; // user input
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
