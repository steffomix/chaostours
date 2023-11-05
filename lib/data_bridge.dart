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
import 'package:chaostours/calendar.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/address.dart';
import 'package:chaostours/tracking.dart';
import 'package:chaostours/event_manager.dart';
import 'package:chaostours/conf/app_settings.dart';
import 'package:chaostours/util.dart';

class DataBridge {
  static final Logger logger = Logger.logger<DataBridge>();

  DataBridge._();
  static DataBridge? _instance;
  factory DataBridge() => _instance ??= DataBridge._();
  static DataBridge get instance => _instance ??= DataBridge._();

  /// trigger driving status
  TrackingStatus triggeredTrackingStatus = TrackingStatus.none;
  Future<void> triggerTrackingStatus(TrackingStatus status) async {
    triggeredTrackingStatus =
        await Cache.cacheTriggerTrackingStatus.save<TrackingStatus>(status);
  }

  // list of serialized CalendarEventId
  List<CalendarEventId> lastCalendarEventIds = [];
  String selectedCalendarId = '';

  ///
  /// backround values
  ///
  GPS? lastGps;
  // gps list from between trackpoints
  GPS? trackPointGpsStartMoving;
  GPS? trackPointGpsStartStanding;
  GPS? trackPointGpslastStatusChange;
  List<GPS> gpsPoints = [];
  List<GPS> smoothGpsPoints = [];
  List<GPS> calcGpsPoints = [];
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
    await Cache.cacheBackgroundAddress.save<String>(currentAddress);
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
        await AppSettings.loadSettings();
        await AppSettings.saveSettings();
        await DataBridge.instance.loadCache();

        while (_serviceRunning) {
          if (AppSettings.backgroundTrackingEnabled) {
            try {
              var now = DateTime.now();
              var lastTick = await Cache.backgroundLastTick.save<DateTime>(now);
              if (lastTick == now) {
                logger.warn('No Background Tick recognized');
              } else {
                var dur = duration(now, lastTick);
                if (dur.inSeconds >
                    AppSettings.backgroundLookupDuration.inSeconds * 3) {
                  logger.warn(
                      'No successful Background GPS since ${dur.inSeconds} seconds. Try to restart Background GPS');
                  await BackgroundTracking.stopTracking();
                  Future.delayed(const Duration(seconds: 1),
                      () => BackgroundTracking.startTracking());
                } else {
                  //logger.log('last BackGround GPS before ${dur.inSeconds} seconds at ${AppSettings.backgroundLookupDuration.inSeconds} seconds interval');
                }
              }
              Cache.backgroundLastTick.save<DateTime>(now);
            } catch (e, stk) {
              logger.error('check background is running $e', stk);
            }
          }

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
            await Future.delayed(const Duration(seconds: 10));
            await Future.delayed(AppSettings.backgroundLookupDuration)
                .onError((error, stackTrace) {
              print('e');
            });
          } catch (e) {
            await Future.delayed(const Duration(seconds: 10));
          }
        }
      });
    }
  }

  /// loaded by foreground and background from Shared preferences
  Future<void> loadCache([GPS? gps]) async {
    try {
      gps ??= await GPS.gps();

      /// address update
      currentAddress = await Cache.cacheBackgroundAddress.load<String>('');

      lastStandingAddress =
          await Cache.cacheBackgroundLastStandingAddress.load('');

      /// status and trigger
      trackingStatus = await Cache.cacheBackgroundTrackingStatus
          .load<TrackingStatus>(TrackingStatus.none);
      triggeredTrackingStatus = await Cache.cacheTriggerTrackingStatus
          .load<TrackingStatus>(TrackingStatus.none);

      /// gps tracking
      lastGps =
          await Cache.cacheBackgroundLastGps.load<GPS>(GPS(gps.lat, gps.lon));
      gpsPoints = await Cache.cacheBackgroundGpsPoints.load<List<GPS>>([]);
      smoothGpsPoints =
          await Cache.cacheBackgroundSmoothGpsPoints.load<List<GPS>>([]);
      calcGpsPoints =
          await Cache.cacheBackgroundCalcGpsPoints.load<List<GPS>>([]);

      /// alias list
      trackPointAliasIdList =
          await Cache.cacheBackgroundAliasIdList.load<List<int>>([]);
      currentAliasIdList =
          await Cache.cacheCurrentAliasIdList.load<List<int>>([]);

      /// status events
      trackPointGpsStartMoving = await Cache.cacheEventBackgroundGpsStartMoving
          .load<GPS>(GPS(gps.lat, gps.lon));
      trackPointGpsStartStanding = await Cache
          .cacheEventBackgroundGpsStartStanding
          .load<GPS>(GPS(gps.lat, gps.lon));
      trackPointGpslastStatusChange = await Cache
          .cacheEventBackgroundGpsLastStatusChange
          .load<GPS>(GPS(gps.lat, gps.lon));

      /// user data
      trackPointUserIdList =
          await Cache.cacheBackgroundUserIdList.load<List<int>>([]);
      trackPointTaskIdList =
          await Cache.cacheBackgroundTaskIdList.load<List<int>>([]);
      trackPointUserNotes =
          await Cache.cacheBackgroundTrackPointUserNotes.load<String>('');

      /// calendar
      lastCalendarEventIds =
          await Cache.calendarLastEventIds.load<List<CalendarEventId>>([]);
    } catch (e, stk) {
      logger.error('loadBackgroundSession: $e', stk);
    }
  }
}
