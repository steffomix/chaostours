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
/*
import 'package:chaostours/cache.dart';
import 'package:chaostours/calendar.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/address.dart';
import 'package:chaostours/tracking.dart';
import 'package:chaostours/event_manager.dart';
import 'package:chaostours/conf/app_settings.dart';
import 'package:chaostours/util.dart';

class _DataBridge {
  static final Logger logger = Logger.logger<DataBridge>();

  DataBridge._();
  static DataBridge? _instance;
  factory DataBridge() => _instance ??= DataBridge._();
  static DataBridge get instance => _instance ??= DataBridge._();

  /// trigger driving status
  TrackingStatus triggeredTrackingStatus = TrackingStatus.none;
  Future<void> triggerTrackingStatus(TrackingStatus status) async {
    triggeredTrackingStatus =
        await Cache.trackingStatusTriggered.save<TrackingStatus>(status);
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
    await Cache.backgroundAddress.save<String>(currentAddress);
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
  Future<void> startService() async {
    if (!_serviceRunning) {
      _serviceRunning = true;
      while (_serviceRunning) {
        Future.microtask(() async {
          if (AppSettings.backgroundTrackingEnabled) {
            try {
              var now = DateTime.now();
              var lastTick = await Cache.backgroundLastTick.load<DateTime>(now);
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
                  logger.log(
                      'last BackGround GPS before ${dur.inSeconds} seconds at ${AppSettings.backgroundLookupDuration.inSeconds} seconds interval');
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
        }).onError(
          (e, stk) {
            logger.error('data bridge service error: $e', stk);
          },
        );
        try {
          var delay = AppSettings.backgroundLookupDuration.inSeconds < 10
              ? const Duration(seconds: 10)
              : AppSettings.backgroundLookupDuration;
          await Future.delayed(delay);
        } catch (e) {
          await Future.delayed(const Duration(seconds: 10));
        }
      }
    }
  }

  /// loaded by foreground and background from Shared preferences
  Future<void> loadCache([GPS? gps]) async {
    try {
      gps ??= await GPS.gps();

      /// status and trigger
      triggeredTrackingStatus = await Cache.trackingStatusTriggered
          .load<TrackingStatus>(TrackingStatus.none);

      /// tracking status
      trackingStatus = await Cache.backgroundTrackingStatus
          .load<TrackingStatus>(TrackingStatus.none);

      /// address update
      currentAddress = await Cache.backgroundAddress.load<String>('');

      lastStandingAddress = await Cache.backgroundLastStandingAddress.load('');

      /// gps tracking
      lastGps = await Cache.backgroundLastGps.load<GPS>(GPS(gps.lat, gps.lon));
      gpsPoints = await Cache.backgroundGpsPoints.load<List<GPS>>([]);
      smoothGpsPoints =
          await Cache.backgroundGpsSmoothPoints.load<List<GPS>>([]);
      calcGpsPoints = await Cache.backgroundGpsCalcPoints.load<List<GPS>>([]);

      /// alias list
      trackPointAliasIdList =
          await Cache.backgroundAliasIdList.load<List<int>>([]);
      currentAliasIdList =
          await Cache.backgroundAliasIdList.load<List<int>>([]);

      /// status events
      trackPointGpsStartMoving =
          await Cache.backgroundGpsStartMoving.load<GPS>(GPS(gps.lat, gps.lon));
      trackPointGpsStartStanding = await Cache.backgroundGpsStartStanding
          .load<GPS>(GPS(gps.lat, gps.lon));
      trackPointGpslastStatusChange = await Cache.backgroundGpsLastStatusChange
          .load<GPS>(GPS(gps.lat, gps.lon));

      /// user data
      trackPointUserIdList =
          await Cache.backgroundUserIdList.load<List<int>>([]);
      trackPointTaskIdList =
          await Cache.backgroundTaskIdList.load<List<int>>([]);
      trackPointUserNotes =
          await Cache.backgroundTrackPointUserNotes.load<String>('');

      /// calendar
      lastCalendarEventIds = await Cache.backgroundCalendarLastEventIds
          .load<List<CalendarEventId>>([]);
    } catch (e, stk) {
      logger.error('loadBackgroundSession: $e', stk);
    }
  }
}
*/