import 'dart:convert';

import 'package:chaostours/globals.dart';
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
  }
  factory TrackPoint() => _instance ??= TrackPoint._();

  /// int _nextId = 0;
  /// contains all trackpoints from current state start or stop
  final List<GPS> gpsPoints = [];
  TrackingStatus _status = TrackingStatus.none;
  TrackingStatus _oldStatus = TrackingStatus.none;
  List<String> _sharedData = [];

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

  Future<void> startShared() async {
    /// load last session from file
    await FileHandler().getStorage();
    String storage = FileHandler.combinePath(
        FileHandler.storages[Storages.appInternal]!, FileHandler.sharedFile);
    String jsonString = await FileHandler.read(storage);

    Map<String, dynamic> json = {
      JsonKeys.status.name: TrackingStatus.none.name,
      JsonKeys.gpsPoints.name: [],
      JsonKeys.address.name: ''
    };
    try {
      json = jsonDecode(jsonString);
    } catch (e, stk) {
      logger.error(e.toString(), stk);
    }

    /// parse status from json
    _status = TrackingStatus.values
        .byName(json[JsonKeys.status.name] ?? TrackingStatus.none.name);

    /// update trackpoints
    updateTrackPointQueue();

    /// only needed if method runs in foreground
    gpsPoints.clear();

    try {
      /// create gpsPoint
      GPS gps = await GPS.gps();

      if (_status == TrackingStatus.none) {
        ///
        _oldStatus = _status = TrackingStatus.standing;
        json[JsonKeys.status.name] = TrackingStatus.standing.name;
        gpsPoints.add(gps);
      } else {
        ///
        for (var p in json[JsonKeys.gpsPoints.name] ?? []) {
          try {
            gpsPoints.add(GPS.toSharedObject(p));
          } catch (e, stk) {
            logger.error(e.toString(), stk);
          }
        }
      }

      /// remember old status
      _oldStatus = _status;

      /// add gps to gpsPoints
      gpsPoints.insert(0, gps);
      while (gpsPoints.length > 300) {
        gpsPoints.removeLast();
      }

      ///
      /// process trackpoint
      ///
      trackPoint();

      /// write possibly new status to json
      json[JsonKeys.status.name] = _status.name;

      /// if nothing changed simply write data back
      if (_status == _oldStatus) {
        json[JsonKeys.gpsPoints.name] =
            gpsPoints.map((e) => e.toSharedString()).toList();
      } else {
        /// status changed
        /// write only last inserted gpsPoint back
        json[JsonKeys.gpsPoints.name] = [gpsPoints.first.toSharedString()];

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
          await ModelAlias.open();
          for (int id in newEntry.idAlias) {
            if (ModelAlias.getAlias(id).status == AliasStatus.restricted) {
              restricted = true;
              break;
            }
          }

          if (!restricted &&
              (!Globals.statusStandingRequireAlias ||
                  (Globals.statusStandingRequireAlias &&
                      newEntry.idAlias.isNotEmpty))) {
            await ModelTrackPoint.insert(newEntry);
            logger.important(
                'Save new Trackpoint #${newEntry.id} with data: \n${newEntry.toString()}');
          } else {
            logger.important(
                'New trackpoint not saved due to app settings- or alias restrictions');
          }
        } else {
          /// new status is standing
          /// remember address from detecting standing
          /// to be used in createModelTrackPoint on next status change
          if (Globals.osmLookupCondition == OsmLookup.always) {
            json[JsonKeys.address.name] =
                (await Address(gps).lookupAddress()).toString();
          }
        }
      }

      /// save status and gpsPoints for next session and foreground live tracking view
      String jsonString = jsonEncode(json);
      await FileHandler.write(storage, jsonString);
    } catch (e, stk) {
      logger.fatal(e.toString(), stk);
    }
  }

  void trackPoint() {
    /*
    /// debug - chnages status after each given gpsPoints
    if (gpsPoints.length > 10) {
      _status =
          _status == TrackingStatus.standing || _status == TrackingStatus.none
              ? TrackingStatus.moving
              : TrackingStatus.standing;
      //_statusChanged(gps);
      return;
    }
    */

    /// query gpsPoints from given time frame
    List<GPS> gpsList = _recentTracks();
    if (gpsPoints.length < 2) {
      return;
    }

    /// check if we stopped standing
    if (_status == TrackingStatus.standing || _status == TrackingStatus.none) {
      if (GPS.distanceoverTrackList(gpsList) > Globals.distanceTreshold) {
        _status = TrackingStatus.moving;
      }

      /// check if we stopped moving
    } else if (_status == TrackingStatus.moving) {
      if (GPS.distanceoverTrackList(gpsList) < Globals.distanceTreshold) {
        _status = TrackingStatus.standing;
      }
    }
  }

  Future<ModelTrackPoint> createModelTrackPoint([GPS? gps]) async {
    if (gps == null) {
      await logger.warn('no gps on trackpoint. lookup foreground gps');
    }
    gps ??= await GPS.gps();
    await logger.log('create new ModelTrackPoint');
    String notes = '';
    List<int> idTask = [];
    List<int> idAlias = [];

    try {
      /// load user inputs
      Shared shared = Shared(SharedKeys.trackPointDown);
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
        (await Shared(SharedKeys.addressStanding).loadString()) ?? ' - ';
    tp.status = _oldStatus;
    tp.timeEnd = DateTime.now();
    tp.idTask = idTask;
    tp.notes = notes;
    return tp;
  }

  /// collect recent Trackpoints since last status changed
  /// and until <timeTreshold>
  /// so that gpsList[0] is most recent
  List<GPS> _recentTracks() {
    List<GPS> gpsList = [];
    DateTime treshold = DateTime.now().subtract(Globals.timeRangeTreshold);
    for (var gps in gpsPoints) {
      if (gps.time.isAfter(treshold)) {
        gpsList.add(gps);
      } else {
        break;
      }
    }
    return gpsList;
  }
}
