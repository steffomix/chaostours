/*
Copyright 2023 Stefan Brinkmann <st.brinkmann@gmail.com>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

import 'package:chaostours/cache.dart';
import 'package:chaostours/app_logger.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/address.dart';
import 'package:chaostours/tracking.dart';
import 'package:chaostours/event_manager.dart';
import 'package:chaostours/conf/app_settings.dart';

class DataBridge {
  static final AppLogger logger = AppLogger.logger<DataBridge>();

  DataBridge._();
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

  String lastCalendarEventId = '';
  String selectedCalendarId = '';

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
  String lastStandingAddress = '';
  Future<String> setAddress(GPS gps) async {
    try {
      currentAddress = (await Address(gps).lookupAddress()).toString();
    } catch (e, stk) {
      currentAddress = e.toString();
      logger.error('set address: $e', stk);
    }
    await Cache.setValue<String>(
        CacheKeys.cacheBackgroundAddress, currentAddress);
    return currentAddress;
  }

  /// trackPoint calculation only
  List<int> trackPointAliasIdList = [];

  /// temporary or user updated alias id list
  List<int> currentAliasIdList = [];

  List<int> trackPointUserIdList = [];
  List<int> trackPointTaskIdList = [];
  String trackPointUserNotes = '';

  /// forground interval
  /// save foreground, load background and fire event
  static bool _serviceRunning = false;
  void stopService() => _serviceRunning = false;
  void startService() {
    if (!_serviceRunning) {
      _serviceRunning = true;
      Future.microtask(() async {
        await DataBridge.instance.reload();
        await AppSettings.loadSettings();
        await AppSettings.saveSettings();
        await DataBridge.instance.loadCache();

        while (_serviceRunning) {
          try {
            var status = trackingStatus.name;
            await loadCache();
            if (status != trackingStatus.name) {
              // trackingstatus has changed
              // reload data
              EventManager.fire<EventOnTrackingStatusChanged>(
                  EventOnTrackingStatusChanged());
            }
            EventManager.fire<EventOnCacheLoaded>(EventOnCacheLoaded());
          } catch (e, stk) {
            logger.error('service execution: $e', stk);
          }
          try {
            await AppLogger.getBackgroundLogs();
          } catch (e, stk) {
            logger.error('getBackgroundLogs: $e', stk);
          }

          await Future.delayed(AppSettings.backgroundLookupDuration);
        }
      });
    }
  }

  /// loaded by foreground and background from Shared preferences
  Future<void> loadCache([GPS? gps]) async {
    try {
      gps ??= await GPS.gps();

      await Cache.reload();

      /// address update
      currentAddress =
          await Cache.getValue<String>(CacheKeys.cacheBackgroundAddress, '');

      lastStandingAddress = await Cache.getValue(
          CacheKeys.cacheBackgroundLastStandingAddress, '');

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
      currentAliasIdList = await Cache.getValue<List<int>>(
          CacheKeys.cacheCurrentAliasIdList, []);

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
      trackPointUserIdList = await Cache.getValue<List<int>>(
          CacheKeys.cacheBackgroundUserIdList, []);
      trackPointTaskIdList = await Cache.getValue<List<int>>(
          CacheKeys.cacheBackgroundTaskIdList, []);
      trackPointUserNotes = await Cache.getValue<String>(
          CacheKeys.cacheBackgroundTrackPointUserNotes, '');

      /// calendar
      lastCalendarEventId =
          await Cache.getValue<String>(CacheKeys.calendarLastEventId, '');
      selectedCalendarId =
          await Cache.getValue<String>(CacheKeys.calendarSelectedId, '');
    } catch (e, stk) {
      logger.error('loadBackgroundSession: $e', stk);
    }
  }
}
