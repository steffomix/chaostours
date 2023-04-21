import 'package:chaostours/cache.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/model/model_trackpoint.dart';
import 'package:chaostours/model/model_alias.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/address.dart';
import 'package:chaostours/background_process/trackpoint.dart';
import 'package:chaostours/event_manager.dart';
import 'package:chaostours/globals.dart';

class DataBridge {
  static final Logger logger = Logger.logger<DataBridge>();

  DataBridge._();
  static DataBridge? _instance;
  factory DataBridge() => _instance ??= DataBridge._();
  static DataBridge get instance => _instance ??= DataBridge._();

  static Future<void> reload() async => await Cache.reload();

  /// trigger status
  bool _triggerStatus = false;
  bool get statusTriggered => _triggerStatus;
  Future<void> triggerStatus() async => await _saveTriggerStatus(true);
  Future<void> triggerStatusExecuted() async => await _saveTriggerStatus(false);
  Future<void> _saveTriggerStatus(bool status) async {
    _triggerStatus = status;
    await Cache.setValue(
        CacheKeys.cacheEventForegroundTriggerStatus, _triggerStatus);
  }

  ///
  /// backround values
  ///
  PendingGps? lastGps;
  // gps list from between trackpoints
  PendingGps? trackPointGpsStartMoving;
  PendingGps? trackPointGpsStartStanding;
  PendingGps? trackPointGpslastStatusChange;
  List<PendingGps> gpsPoints = [];
  List<PendingGps> smoothGpsPoints = [];
  List<PendingGps> calcGpsPoints = [];
  // ignore: prefer_final_fields
  TrackingStatus trackingStatus = TrackingStatus.none;

  String currentAddress = '';
  Future<void> setAddress(GPS gps) async {
    try {
      currentAddress = (await Address(gps).lookupAddress()).toString();
    } catch (e, stk) {
      currentAddress = e.toString();
      logger.error('set address: $e', stk);
    }
  }

  List<int> trackPointAliasIdList = [];
  List<int> trackPointUserIdList = [];
  List<int> trackPointTaskIdList = [];
  String trackPointUserNotes = '';

  /// forground interval
  /// save foreground, load background and fire event
  static bool _serviceRunning = false;
  void stopService() => _serviceRunning = false;
  startService() {
    if (!_serviceRunning) {
      _serviceRunning = true;
      Future.microtask(() async {
        while (_serviceRunning) {
          try {
            await Cache.reload();
            var status = trackingStatus.name;
            await loadBackgroundSession();
            if (status != trackingStatus.name) {
              // trackingstatus has changed
              // reload data
              await ModelTrackPoint.open();
              await ModelAlias.open();
              EventManager.fire<EventOnTrackingStatusChanged>(
                  EventOnTrackingStatusChanged());
            }
            EventManager.fire<EventOnCacheLoaded>(EventOnCacheLoaded());
          } catch (e, stk) {
            logger.error('service execution: $e', stk);
          }
          await Future.delayed(Globals.trackPointInterval);
        }
      });
    }
  }

  /// load foreground by background
  Future<void> loadTriggerStatus() async {
    _triggerStatus = await Cache.getValue<bool>(
        CacheKeys.cacheEventForegroundTriggerStatus, false);
  }

  /// load by foreground only
  Future<void> loadBackgroundSession() async {
    GPS.gps().then((GPS gps) async {
      /// address update
      currentAddress =
          await Cache.getValue<String>(CacheKeys.cacheBackgroundAddress, '');

      /// status and trigger
      _triggerStatus = await Cache.getValue<bool>(
          CacheKeys.cacheEventForegroundTriggerStatus, false);
      trackingStatus = await Cache.getValue<TrackingStatus>(
          CacheKeys.cacheBackgroundTrackingStatus, TrackingStatus.none);

      /// gps tracking
      lastGps = await Cache.getValue<PendingGps>(
          CacheKeys.cacheBackgroundLastGps, PendingGps(gps.lat, gps.lon));
      gpsPoints = await Cache.getValue<List<PendingGps>>(
          CacheKeys.cacheBackgroundGpsPoints, []);
      calcGpsPoints = await Cache.getValue<List<PendingGps>>(
          CacheKeys.cacheBackgroundCalcGpsPoints, []);
      smoothGpsPoints = await Cache.getValue<List<PendingGps>>(
          CacheKeys.cacheBackgroundSmoothGpsPoints, []);

      /// status events
      trackPointGpsStartMoving = await Cache.getValue<PendingGps>(
          CacheKeys.cacheEventBackgroundGpsStartMoving,
          PendingGps(gps.lat, gps.lon));
      trackPointGpsStartStanding = await Cache.getValue<PendingGps>(
          CacheKeys.cacheEventBackgroundGpsStartStanding,
          PendingGps(gps.lat, gps.lon));
      trackPointGpslastStatusChange = await Cache.getValue<PendingGps>(
          CacheKeys.cacheEventBackgroundGpsLastStatusChange,
          PendingGps(gps.lat, gps.lon));

      /*
      trackPointAliasIdList = await Cache.getValue<List<int>>(
          CacheKeys.cacheBackgroundAliasIdList, []);
      trackPointTaskIdList = await Cache.getValue<List<int>>(
          CacheKeys.cacheBackgroundTaskIdList, []);
      trackPointUserIdList = await Cache.getValue<List<int>>(
          CacheKeys.cacheBackgroundUserIdList, []);
      trackPointUserNotes = await Cache.getValue<String>(
          CacheKeys.cacheBackgroundTrackPointUserNotes, '');
          */
    }).onError((e, stackTrace) {
      logger.error('get gps for loadbackgroundSession: $e', stackTrace);
    });
  }

  /// save session
  /// some values are saved directly or on events
  Future<void> saveSession(GPS gps) async {
    //
    await Cache.setValue<TrackingStatus>(
        CacheKeys.cacheBackgroundTrackingStatus, trackingStatus);

    await Cache.setValue<String>(
        CacheKeys.cacheBackgroundAddress, currentAddress);

    await Cache.setValue<List<PendingGps>>(
        CacheKeys.cacheBackgroundGpsPoints, gpsPoints);

    await Cache.setValue<List<PendingGps>>(
        CacheKeys.cacheBackgroundSmoothGpsPoints, smoothGpsPoints);

    await Cache.setValue<List<PendingGps>>(
        CacheKeys.cacheBackgroundCalcGpsPoints, calcGpsPoints);

    await Cache.setValue<PendingGps>(CacheKeys.cacheBackgroundLastGps,
        lastGps ?? PendingGps(gps.lat, gps.lon));
  }
}
