import 'package:chaostours/cache.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/model/model_trackpoint.dart';
import 'package:chaostours/model/model_alias.dart';
import 'package:chaostours/gps.dart';
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

  ///
  /// foreground values
  ///
  List<ModelTrackPoint> trackPointUpdates = [];
  PendingModelTrackPoint pendingTrackPoint =
      PendingModelTrackPoint.pendingTrackPoint;

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
  PendingGps? gpsStartMoving;
  PendingGps? gpsStartStanding;
  List<PendingGps> gpsPoints = [];
  List<PendingGps> smoothGpsPoints = [];
  List<PendingGps> calcGpsPoints = [];
  // ignore: prefer_final_fields
  TrackingStatus trackingStatus = TrackingStatus.none;

  String address = '';
  List<ModelTrackPoint> recentTrackPoints = [];
  List<ModelTrackPoint> lastVisitedTrackPoints = [];
  List<int> aliasIdList = [];
  List<int> userIdList = [];
  List<int> taskIdList = [];
  String trackPointUserNotes = '';

  /// make sure ModelAlias is opened and Cache is reloaded
  Future<void> updateAliasIdList(GPS gps) async {
    /// write new entry only if no restricted alias is present
    var restricted = false;

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
        restricted = true;
        aliasList.clear();
        break;
      }

      /// add alias
      aliasList.add(alias);
    }

    if (!restricted &&
        (!Globals.statusStandingRequireAlias ||
            (Globals.statusStandingRequireAlias && aliasList.isNotEmpty))) {
      aliasIdList = aliasList.map((e) => e.id).toList();
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
              await Cache.reload();
              try {
                await loadBackground(gps);
              } catch (e, stk) {
                logger.error('load background cache failed: $e', stk);
              }
              try {
                /// save foreground
                await saveForeground(gps);
              } catch (e, stk) {
                logger.error('save foreground failed: $e', stk);
              }
              await EventManager.fire<EventOnCacheLoaded>(EventOnCacheLoaded());
            }).onError((error, stackTrace) {
              logger.error('cache listen $error', stackTrace);
            });
            await Globals.loadSettings();
          } catch (e, stk) {
            logger.error('gps $e', stk);
          }
          await Future.delayed(Globals.trackPointInterval);
        }
      });
    }
  }

  /// save foreground
  Future<void> saveForeground(GPS gps) async {
    await Cache.setValue<PendingModelTrackPoint>(
        CacheKeys.cacheForegroundActiveTrackPoint, pendingTrackPoint);

    await Cache.setValue<List<ModelTrackPoint>>(
        CacheKeys.cacheForegroundTrackPointUpdates, trackPointUpdates);
  }

  /// load foreground
  Future<void> loadForeground(GPS gps) async {
    pendingTrackPoint = await Cache.getValue<PendingModelTrackPoint>(
      CacheKeys.cacheForegroundActiveTrackPoint,
      PendingModelTrackPoint.pendingTrackPoint,
    );

    trackPointUpdates = await Cache.getValue<List<ModelTrackPoint>>(
        CacheKeys.cacheForegroundTrackPointUpdates, []);

    _triggerStatus = await Cache.getValue<bool>(
        CacheKeys.cacheForegroundTriggerStatus, false);
  }

  /// load background
  Future<void> loadBackground(GPS gps) async {
    _triggerStatus = await Cache.getValue<bool>(
        CacheKeys.cacheForegroundTriggerStatus, false);

    recentTrackPoints = await Cache.getValue<List<ModelTrackPoint>>(
        CacheKeys.cacheBackgroundRecentTrackpoints, []);

    lastVisitedTrackPoints = await Cache.getValue<List<ModelTrackPoint>>(
        CacheKeys.cacheBackgroundLastVisitedTrackpoints, []);

    address =
        await Cache.getValue<String>(CacheKeys.cacheBackgroundAddress, '');

    calcGpsPoints = await Cache.getValue<List<PendingGps>>(
        CacheKeys.cacheBackgroundCalcGpsPoints, []);

    gpsPoints = await Cache.getValue<List<PendingGps>>(
        CacheKeys.cacheBackgroundGpsPoints, []);

    lastGps = await Cache.getValue<PendingGps>(
        CacheKeys.cacheBackgroundLastGps, PendingGps(gps.lat, gps.lon));

    gpsStartMoving = await Cache.getValue<PendingGps>(
        CacheKeys.cacheBackgroundGpsStartMoving, PendingGps(gps.lat, gps.lon));
    gpsStartStanding = await Cache.getValue<PendingGps>(
        CacheKeys.cacheBackgroundGpsStartStanding,
        PendingGps(gps.lat, gps.lon));

    smoothGpsPoints = await Cache.getValue<List<PendingGps>>(
        CacheKeys.cacheBackgroundSmoothGpsPoints, []);

    trackingStatus = await Cache.getValue<TrackingStatus>(
        CacheKeys.cacheBackgroundTrackingStatus, TrackingStatus.none);

    trackPointUserNotes = await Cache.getValue<String>(
        CacheKeys.cacheBackgroundTrackPointUserNotes, '');

    aliasIdList = await Cache.getValue<List<int>>(
        CacheKeys.cacheBackgroundAliasIdList, []);
    taskIdList = await Cache.getValue<List<int>>(
        CacheKeys.cacheBackgroundTaskIdList, []);
    userIdList = await Cache.getValue<List<int>>(
        CacheKeys.cacheBackgroundUserIdList, []);
  }

  /// load background
  Future<void> saveBackground(GPS gps) async {
    await Cache.setValue<bool>(
        CacheKeys.cacheForegroundTriggerStatus, _triggerStatus);
    //
    await Cache.setValue<TrackingStatus>(
        CacheKeys.cacheBackgroundTrackingStatus, trackingStatus);

    await Cache.setValue<List<ModelTrackPoint>>(
        CacheKeys.cacheBackgroundRecentTrackpoints, recentTrackPoints);

    await Cache.setValue<List<ModelTrackPoint>>(
        CacheKeys.cacheBackgroundLastVisitedTrackpoints,
        lastVisitedTrackPoints);

    await Cache.setValue<String>(CacheKeys.cacheBackgroundAddress, address);

    await Cache.setValue<List<PendingGps>>(
        CacheKeys.cacheBackgroundGpsPoints, gpsPoints);

    await Cache.setValue<List<PendingGps>>(
        CacheKeys.cacheBackgroundSmoothGpsPoints, smoothGpsPoints);

    await Cache.setValue<List<PendingGps>>(
        CacheKeys.cacheBackgroundCalcGpsPoints, calcGpsPoints);

    await Cache.setValue<PendingGps>(CacheKeys.cacheBackgroundLastGps,
        lastGps ?? PendingGps(gps.lat, gps.lon));

    await Cache.setValue<PendingGps>(CacheKeys.cacheBackgroundGpsStartMoving,
        gpsStartMoving ?? PendingGps(gps.lat, gps.lon));
    await Cache.setValue<PendingGps>(CacheKeys.cacheBackgroundGpsStartStanding,
        gpsStartStanding ?? PendingGps(gps.lat, gps.lon));

    await Cache.setValue<String>(
        CacheKeys.cacheBackgroundTrackPointUserNotes, trackPointUserNotes);
    await Cache.setValue<List<int>>(
        CacheKeys.cacheBackgroundAliasIdList, aliasIdList);
    await Cache.setValue<List<int>>(
        CacheKeys.cacheBackgroundTaskIdList, taskIdList);
    await Cache.setValue<List<int>>(
        CacheKeys.cacheBackgroundUserIdList, userIdList);
  }
}
