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
  // foreground only
  List<int> trackPointPreselectedUserIdList = [];

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
            GPS.gps().then((GPS gps) async {
              try {
                await Cache.reload();
                var status = trackingStatus.name;
                await loadBackground(gps);
                if (status != trackingStatus.name) {
                  // reload modelTrackpoint
                  ModelTrackPoint.open();
                  EventManager.fire<EventOnTrackingStatusChanged>(
                      EventOnTrackingStatusChanged());
                }
                await EventManager.fire<EventOnCacheLoaded>(
                    EventOnCacheLoaded());
              } catch (e, stk) {
                logger.error('load background cache failed: $e', stk);
              }
            }).onError((e, stackTrace) {
              logger.error('Service $e', stackTrace);
            });
          } catch (e, stk) {
            logger.error('gps $e', stk);
          }
          await Future.delayed(Globals.trackPointInterval);
        }
      });
    }
  }

  Future<void> saveUserInput() async {
    /// reset userdata
    await Cache.setValue<List<int>>(
        CacheKeys.cacheBackgroundTaskIdList, trackPointTaskIdList);
    await Cache.setValue<List<int>>(
        CacheKeys.cacheBackgroundUserIdList, trackPointUserIdList);
    await Cache.setValue<String>(
        CacheKeys.cacheBackgroundTrackPointUserNotes, trackPointUserNotes);
  }

  /// load foreground by background
  Future<void> loadForeground(GPS gps) async {
    _triggerStatus = await Cache.getValue<bool>(
        CacheKeys.cacheEventForegroundTriggerStatus, false);
  }

  /// load background by foreground
  Future<void> loadBackground(GPS gps) async {
    _triggerStatus = await Cache.getValue<bool>(
        CacheKeys.cacheEventForegroundTriggerStatus, false);

    currentAddress =
        await Cache.getValue<String>(CacheKeys.cacheBackgroundAddress, '');

    calcGpsPoints = await Cache.getValue<List<PendingGps>>(
        CacheKeys.cacheBackgroundCalcGpsPoints, []);

    gpsPoints = await Cache.getValue<List<PendingGps>>(
        CacheKeys.cacheBackgroundGpsPoints, []);

    lastGps = await Cache.getValue<PendingGps>(
        CacheKeys.cacheBackgroundLastGps, PendingGps(gps.lat, gps.lon));

    trackPointGpsStartMoving = await Cache.getValue<PendingGps>(
        CacheKeys.cacheEventBackgroundGpsStartMoving,
        PendingGps(gps.lat, gps.lon));
    trackPointGpsStartStanding = await Cache.getValue<PendingGps>(
        CacheKeys.cacheEventBackgroundGpsStartStanding,
        PendingGps(gps.lat, gps.lon));
    trackPointGpslastStatusChange = await Cache.getValue<PendingGps>(
        CacheKeys.cacheEventBackgroundGpsLastStatusChange,
        PendingGps(gps.lat, gps.lon));

    smoothGpsPoints = await Cache.getValue<List<PendingGps>>(
        CacheKeys.cacheBackgroundSmoothGpsPoints, []);

    trackingStatus = await Cache.getValue<TrackingStatus>(
        CacheKeys.cacheBackgroundTrackingStatus, TrackingStatus.none);

    trackPointUserNotes = await Cache.getValue<String>(
        CacheKeys.cacheBackgroundTrackPointUserNotes, '');

    trackPointAliasIdList = await Cache.getValue<List<int>>(
        CacheKeys.cacheBackgroundAliasIdList, []);
    trackPointTaskIdList = await Cache.getValue<List<int>>(
        CacheKeys.cacheBackgroundTaskIdList, []);
    trackPointUserIdList = await Cache.getValue<List<int>>(
        CacheKeys.cacheBackgroundUserIdList, []);
  }

  /// load background
  Future<void> saveBackground(GPS gps) async {
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

    await Cache.setValue<List<int>>(
        CacheKeys.cacheBackgroundAliasIdList, trackPointAliasIdList);
  }
}
