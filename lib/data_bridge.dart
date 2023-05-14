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

  DataBridge._() {
    // reset background logger
    Cache.setValue<List<String>>(CacheKeys.backgroundLogger, []);
  }
  static DataBridge? _instance;
  factory DataBridge() => _instance ??= DataBridge._();
  static DataBridge get instance => _instance ??= DataBridge._();

  Future<void> reload() async => await Cache.reload();

  /// trigger driving status
  TrackingStatus triggeredTrackingStatus = TrackingStatus.none;
  Future<void> triggerTrackingStatus(TrackingStatus status) async {
    triggeredTrackingStatus = await Cache.setValue<TrackingStatus>(
        CacheKeys.cacheTriggerTrackingStatus, status);
  }

  String lastCalendarId = '';

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
    await Cache.setValue<String>(
        CacheKeys.cacheBackgroundAddress, currentAddress);
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
            await loadCache();
            if (status != trackingStatus.name) {
              // trackingstatus has changed
              // reload data
              await Cache.reload();
              await ModelTrackPoint.open();
              await ModelAlias.open();
              EventManager.fire<EventOnTrackingStatusChanged>(
                  EventOnTrackingStatusChanged());
            }
            EventManager.fire<EventOnCacheLoaded>(EventOnCacheLoaded());
          } catch (e, stk) {
            logger.error('service execution: $e', stk);
          }
          try {
            await Logger.getBackgroundLogs();
          } catch (e, stk) {
            logger.error('getBackgroundLogs: $e', stk);
          }
          await Future.delayed(Globals.trackPointInterval);
        }
      });
    }
  }

  /// load foreground by background
  Future<void> loadTriggerStatus() async {
    triggeredTrackingStatus = await Cache.getValue<TrackingStatus>(
        CacheKeys.cacheTriggerTrackingStatus, TrackingStatus.none);
  }

  /// loaded by foreground and background
  Future<void> loadCache([GPS? gps]) async {
    try {
      gps ??= await GPS.gps();

      await Cache.reload();

      /// address update
      currentAddress =
          await Cache.getValue<String>(CacheKeys.cacheBackgroundAddress, '');

      /// status and trigger
      trackingStatus = await Cache.getValue<TrackingStatus>(
          CacheKeys.cacheBackgroundTrackingStatus, TrackingStatus.none);
      triggeredTrackingStatus = await Cache.getValue<TrackingStatus>(
          CacheKeys.cacheTriggerTrackingStatus, TrackingStatus.none);

      /// gps tracking
      lastGps = await Cache.getValue<PendingGps>(
          CacheKeys.cacheBackgroundLastGps, PendingGps(gps.lat, gps.lon));
      gpsPoints = await Cache.getValue<List<PendingGps>>(
          CacheKeys.cacheBackgroundGpsPoints, []);
      smoothGpsPoints = await Cache.getValue<List<PendingGps>>(
          CacheKeys.cacheBackgroundSmoothGpsPoints, []);
      calcGpsPoints = await Cache.getValue<List<PendingGps>>(
          CacheKeys.cacheBackgroundCalcGpsPoints, []);

      /// alias list
      trackPointAliasIdList = await Cache.getValue<List<int>>(
          CacheKeys.cacheBackgroundAliasIdList, []);

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

      /// user data
      ///

      trackPointUserIdList = await Cache.getValue<List<int>>(
          CacheKeys.cacheBackgroundUserIdList, []);
      trackPointTaskIdList = await Cache.getValue<List<int>>(
          CacheKeys.cacheBackgroundTaskIdList, []);

      trackPointUserNotes = await Cache.getValue<String>(
          CacheKeys.cacheBackgroundTrackPointUserNotes, '');

      /// calendar
      lastCalendarId =
          await Cache.getValue<String>(CacheKeys.lastCalendarEvent, '');
    } catch (e, stk) {
      logger.error('loadBackgroundSession: $e', stk);
    }
  }
}
