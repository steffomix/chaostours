import 'dart:convert';

import 'package:chaostours/globals.dart';
import 'package:chaostours/app_loader.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/address.dart';
import 'package:chaostours/model/model_trackpoint.dart';
import 'package:chaostours/model/model_alias.dart'; // for read only
import 'package:chaostours/util.dart' as util;
import 'package:chaostours/logger.dart';
import 'package:chaostours/shared.dart';
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
  TrackingStatus _status = TrackingStatus.none;
  TrackingStatus _oldStatus = TrackingStatus.none;

  /// updates modified trackpoints from foreground task
  Future<void> updateTrackPointQueue() async {
    Shared shared = Shared(SharedKeys.updateTrackPointQueue);
    try {
      List<String> queue = await shared.loadList() ?? [];
      for (var row in queue) {
        ModelTrackPoint tp = ModelTrackPoint.toModel(row);
        await ModelTrackPoint.update(tp);
      }
    } catch (e, stk) {
      logger.error(e.toString(), stk);
    }
    shared.saveList([]);
  }

  Future<void> startShared({required double lat, required double lon}) async {
    /// only needed if method runs in foreground
    gpsPoints.clear();

    /// create gpsPoint
    GPS gps = GPS(lat, lon);

    // init app
    // await AppLoader.webKey(); // not needed
    await AppLoader.loadSharedSettings();
    await AppLoader.initializeStorages();
    if (FileHandler.storagePath == null) {
      logger.warn('No valid storage key, skip trackpoint');
      return;
    }

    await ModelTrackPoint.open();
    SharedLoader shared = SharedLoader.instance;
    await shared.loadBackground();

    // cache gps
    // the time can't be too long due to this task gets killed anyway
    Globals.cacheGpsTime = const Duration(seconds: 30);
    GPS.lastGps = GPS(lat, lon);

    /// parse status from json
    _status = shared.status;

    /// update trackpoints
    updateTrackPointQueue();

    try {
      gpsPoints.add(gps);
      gpsPoints.addAll(shared.gpsPoints);

      if (shared.status == TrackingStatus.none) {
        /// app start, no status yet
        _oldStatus = _status = TrackingStatus.standing;
      }

      /// remember old status
      _oldStatus = _status;

      while (gpsPoints.length > 1000) {
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
          /// create Model from where we detected status standing
          /// which is the last gpsPoints entry
          ModelTrackPoint newEntry =
              await createModelTrackPoint(gpsPoints.last);

          /// write new entry only if no restricted alias is present
          var restricted = false;

          /// if this area is not restricted
          /// we reuse this list to update lastVisited
          List<ModelAlias> aliasList = [];
          for (int id in newEntry.idAlias) {
            var alias = ModelAlias.getAlias(id);
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
                      newEntry.idAlias.isNotEmpty))) {
            /// insert new entry
            /// don't forget to load database first
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
            shared.address = (await Address(gps).lookupAddress()).toString();
          }
        } else {
          /// new status is standing
          /// remember address from detecting standing
          /// to be used in createModelTrackPoint on next status change
          if (Globals.osmLookupCondition == OsmLookup.onStatus) {
            shared.address = (await Address(gps).lookupAddress()).toString();
          }
        }

        /// status changed
        /// write only last inserted gpsPoint back
        gpsPoints.clear();
        gpsPoints.add(gps);
      }
      if (Globals.osmLookupCondition == OsmLookup.always) {
        shared.address = (await Address(gps).lookupAddress()).toString();
      }

      /// save status and gpsPoints for next session and foreground live tracking view
      await shared.saveBackground(
          status: _status,
          gpsPoints: gpsPoints,
          lastGps: gps,
          address: shared.address);
    } catch (e, stk) {
      logger.fatal(e.toString(), stk);
    }
  }

  void trackPoint() {
    // get gpsPoints of globals time range
    // to measure movement
    List<GPS> gpsList = [];
    DateTime treshold = DateTime.now().subtract(Globals.timeRangeTreshold);
    for (var gps in gpsPoints) {
      if (gps.time.isAfter(treshold)) {
        gpsList.add(gps);
      } else {
        break;
      }
    }

    if (gpsPoints.length < 2) {
      return;
    }

    /// check if we stopped standing
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

  Future<ModelTrackPoint> createModelTrackPoint(GPS gps) async {
    await logger.log('create new ModelTrackPoint');
    String notes = '';
    List<int> idTask = [];
    List<int> idAlias = [];

    try {
      /// load user inputs
      Shared shared = Shared(SharedKeys.activeTrackPoint);
      String? tpRow = await shared.loadString();
      if (tpRow == null) {
        logger.warn('no trackPoint Data found in SharedKeys.trackPointDown');
      } else {
        ModelTrackPoint tps = ModelTrackPoint.toSharedModel(tpRow);
        notes = tps.notes;
        idTask = tps.idTask;
        idAlias = tps.idAlias;
      }
    } catch (e, stk) {
      logger.error('load shared data for trackPoint: ${e.toString()}', stk);
    }
    ModelTrackPoint tp = ModelTrackPoint(
        gps: gps,
        trackPoints: gpsPoints.map((e) => e).toList(),
        idAlias: idAlias,
        timeStart: gpsPoints.last.time);
    tp.address =
        SharedLoader.instance.address; // should be loaded at this point
    tp.status = _oldStatus;
    tp.timeEnd = DateTime.now();
    tp.idTask = idTask;
    tp.notes = notes;
    return tp;
  }
}
