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
  Future<void> triggerStatus() async {
    _triggerStatus = true;
    await Cache.setValue(
        CacheKeys.cacheForegroundTriggerStatus, _triggerStatus);
  }

  void triggerStatusExecuted() => _triggerStatus = false;

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

  /// make sure ModelAlias is opened and Cache is reloaded
  Future<void> updateAliasIdList(GPS gps) async {
    /// write new entry only if no restricted alias is present
    var restrictedAlias = false;

    /// if this area is not restricted
    /// we reuse this list to update lastVisited
    List<ModelAlias> aliasList = [];

    for (ModelAlias alias in ModelAlias.nextAlias(gps: gps)) {
      if (alias.deleted) {
        // don't add deleted items
        continue;
      }

      /// if there is only one restricted alias
      /// skip the whole thing and save nothing
      if (alias.status == AliasStatus.restricted) {
        restrictedAlias = true;
        aliasList.clear();
        break;
      }

      /// add alias
      aliasList.add(alias);
    }

    if (!restrictedAlias &&
        (!Globals.statusStandingRequireAlias ||
            (Globals.statusStandingRequireAlias && aliasList.isNotEmpty))) {
      trackPointAliasIdList = aliasList.map((e) => e.id).toList();
    } else {
      logger.log(
          'New trackpoint not saved due to app settings- or alias restrictions');
    }
  }

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

  /// load foreground by background
  Future<void> loadForeground(GPS gps) async {
    _triggerStatus = await Cache.getValue<bool>(
        CacheKeys.cacheForegroundTriggerStatus, false);
  }

  /// load background by foreground
  Future<void> loadBackground(GPS gps) async {
    _triggerStatus = await Cache.getValue<bool>(
        CacheKeys.cacheForegroundTriggerStatus, false);

    currentAddress =
        await Cache.getValue<String>(CacheKeys.cacheBackgroundAddress, '');

    calcGpsPoints = await Cache.getValue<List<PendingGps>>(
        CacheKeys.cacheBackgroundCalcGpsPoints, []);

    gpsPoints = await Cache.getValue<List<PendingGps>>(
        CacheKeys.cacheBackgroundGpsPoints, []);

    lastGps = await Cache.getValue<PendingGps>(
        CacheKeys.cacheBackgroundLastGps, PendingGps(gps.lat, gps.lon));

    trackPointGpsStartMoving = await Cache.getValue<PendingGps>(
        CacheKeys.cacheBackgroundGpsStartMoving, PendingGps(gps.lat, gps.lon));
    trackPointGpsStartStanding = await Cache.getValue<PendingGps>(
        CacheKeys.cacheBackgroundGpsStartStanding,
        PendingGps(gps.lat, gps.lon));
    trackPointGpslastStatusChange = await Cache.getValue<PendingGps>(
        CacheKeys.cacheBackgroundGpsLastStatusChange,
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
    await Cache.setValue<bool>(
        CacheKeys.cacheForegroundTriggerStatus, _triggerStatus);
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

    await Cache.setValue<PendingGps>(CacheKeys.cacheBackgroundGpsStartMoving,
        trackPointGpsStartMoving ?? PendingGps(gps.lat, gps.lon));
    await Cache.setValue<PendingGps>(CacheKeys.cacheBackgroundGpsStartStanding,
        trackPointGpsStartStanding ?? PendingGps(gps.lat, gps.lon));

    await Cache.setValue<String>(
        CacheKeys.cacheBackgroundTrackPointUserNotes, trackPointUserNotes);
    await Cache.setValue<List<int>>(
        CacheKeys.cacheBackgroundAliasIdList, trackPointAliasIdList);
    await Cache.setValue<List<int>>(
        CacheKeys.cacheBackgroundTaskIdList, trackPointTaskIdList);
    await Cache.setValue<List<int>>(
        CacheKeys.cacheBackgroundUserIdList, trackPointUserIdList);
  }
}
