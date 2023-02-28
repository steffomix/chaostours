import 'package:chaostours/globals.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/address.dart';
import 'package:chaostours/model/model_trackpoint.dart';
import 'package:chaostours/model/model_alias.dart'; // for read only
import 'package:chaostours/util.dart' as util;
import 'package:chaostours/logger.dart';
import 'package:chaostours/shared.dart';
import 'package:chaostours/app_settings.dart';

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
    /// update trackpoints
    updateTrackPointQueue();

    /// only needed if method runs in foreground
    gpsPoints.clear();

    try {
      /// load shared data
      Shared shared = Shared(SharedKeys.trackPointUp);
      List<String> sh = _sharedData = await shared.loadList() ?? [];
      logger.log('#### Shared data from background process');
      for (var i in sh) {
        logger.log(i);
      }

      /// create gpsPoint
      GPS gps = await GPS.gps();

      /// check for first run
      if (_sharedData.isEmpty) {
        _oldStatus = _status = TrackingStatus.standing;
        _sharedData.add(_status.name);
        _sharedData.add(gps.toSharedString());
        await shared.saveList(_sharedData);
        await Shared(SharedKeys.addressStanding)
            .saveString((await Address(gps).lookupAddress()).toString());
        return;
      }

      /// parse shared status from last session
      try {
        _status = TrackingStatus.values.byName(_sharedData.removeAt(0));
      } catch (e) {
        logger.error(
            '"${_sharedData[0]}" is not a valid shared TrackingStatus. Default to "standing"',
            null);
        _status = TrackingStatus.standing;
      }

      /// remember old status
      _oldStatus = _status;

      /// parse shared gpsPoints from last session
      if (_sharedData.isNotEmpty) {
        // remove status
        for (var row in _sharedData) {
          try {
            gpsPoints.add(GPS.toSharedObject(row));
          } catch (e) {
            logger.error('"$row" is not valid shared GPS Data', null);
          }
        }
      }

      /// process trackpoint
      trackPoint(gps);

      /// write shared data for next session
      _sharedData.clear();
      _sharedData.add(_status.name);

      /// if nothing changed simply write data back
      if (_status == _oldStatus) {
        for (var gps in gpsPoints) {
          _sharedData.add(gps.toSharedString());
        }
      } else {
        /// status changed
        /// write only last inserted gpsPoint back
        _sharedData.add(gpsPoints.first.toSharedString());

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
          await Shared(SharedKeys.addressStanding)
              .saveString((await Address(gps).lookupAddress()).toString());
        }
      }

      /// save status and gpsPoints for next session and foreground live tracking view
      await shared.saveList(_sharedData);
    } catch (e, stk) {
      logger.fatal(e.toString(), stk);
    }
  }

  void trackPoint(GPS gps) {
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
    logger.log('processing trackpoint ${gps.toString()}');

    /// add gps to gpsPoints
    gpsPoints.insert(0, gps);
    while (gpsPoints.length > 300) {
      gpsPoints.removeLast();
    }

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
