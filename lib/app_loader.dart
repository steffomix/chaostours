import 'package:flutter/services.dart';
import 'dart:io' as io;

///
import 'package:chaostours/model/model_alias.dart';
import 'package:chaostours/model/model_trackpoint.dart';
import 'package:chaostours/model/model_task.dart';
import 'package:chaostours/model/model_user.dart';
import 'package:chaostours/background_process/tracking.dart';
import 'package:chaostours/event_manager.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/permission_checker.dart';
import 'package:chaostours/globals.dart';
import 'package:chaostours/cache.dart';
import 'package:chaostours/data_bridge.dart';
import 'package:chaostours/gps.dart';

class AppLoader {
  static Logger logger = Logger.logger<AppLoader>();

  ///
  /// preload recources
  static Future<void> preload() async {
    try {
      Logger.logLevel = LogLevel.verbose;
      logger.important('start Preload sequence...');
      await webKey();
      await DataBridge.instance.reload();
      await Globals.loadSettings();
      await Globals.saveSettings();
      await DataBridge.instance.loadCache();
      await DataBridge.instance.loadTriggerStatus();

      await ModelTrackPoint.open();
      await ModelUser.open();
      await ModelTask.open();
      await ModelAlias.open();

      /// check if alias is available
      if (await PermissionChecker.checkLocation()) {
        try {
          DataBridge.instance.trackPointAliasIdList =
              await Cache.setValue<List<int>>(
                  CacheKeys.cacheBackgroundAliasIdList,
                  ModelAlias.nextAlias(gps: await GPS.gps())
                      .map((e) => e.id)
                      .toList());
        } catch (e, stk) {
          logger.error('preload alias: $e', stk);
        }
      }
      await PermissionChecker.checkAll();
      //
      await BackgroundTracking.initialize();
      if (await PermissionChecker.checkLocation() &&
          Globals.backgroundTrackingEnabled) {
        await BackgroundTracking.startTracking();
      }
      ticks();
    } catch (e, stk) {
      logger.error('preload $e', stk);
    }
  }

  ///
  /// load ssh key for https connections
  static Future<void> webKey() async {
    ByteData data =
        await PlatformAssetBundle().load('assets/ca/lets-encrypt-r3.pem');
    io.SecurityContext.defaultContext
        .setTrustedCertificatesBytes(data.buffer.asUint8List());
    logger.log('SSL Key loaded');
  }

  //
  static Future<void> loadAssetDatabase() async {
    logger.important('load databasde from asset');

    ///
    if (ModelAlias.length < 1) {
      await ModelAlias.openFromAsset();
      await ModelAlias.write();
    }
    if (ModelUser.length < 1) {
      await ModelUser.openFromAsset();
      await ModelUser.write();
    }
    if (ModelTask.length < 1) {
      await ModelTask.openFromAsset();
      await ModelTask.write();
    }
  }

  static Future<void> ticks() async {
    DataBridge.instance.startService();
    _appTick();
    _addressTick();
    Logger.listenOnTick();
  }

  static Future<void> _appTick() async {
    while (true) {
      var event = EventOnAppTick();
      try {
        EventManager.fire<EventOnAppTick>(event);
      } catch (e, stk) {
        logger.error('appTick #${event.id} failed: $e', stk);
      }
      await Future.delayed(Globals.appTickDuration);
    }
  }

  static Future<void> _addressTick() async {
    while (true) {
      var event = EventOnAddressLookup();
      try {
        if (Globals.osmLookupInterval.inMinutes > 0) {
          EventManager.fire<EventOnAddressLookup>(event);
        }
      } catch (e, stk) {
        logger.error('appTick #${event.eventId} failed: $e', stk);
      }
      await Future.delayed(Globals.osmLookupInterval);
    }
  }
/*
  ///
  /// load calendar api from credentials asset file
  static CalendarApi? _calendarApi;
  static final List<String> scopes = [CalendarApi.calendarScope];
  static const String credentialsFile =
      'assets/google-api/service-account.json';

  ///
  static Future<CalendarApi> calendarApiFromCredentials(
      {forceReload = false}) async {
    if (_calendarApi != null && !forceReload) {
      return Future<CalendarApi>.value(_calendarApi);
    }
    String jsonString = await rootBundle.loadString(credentialsFile);
    AutoRefreshingAuthClient client = await clientViaServiceAccount(
        ServiceAccountCredentials.fromJson(jsonString), scopes);
    CalendarApi api = CalendarApi(client);
    _calendarApi = api;
    logger.log('Calendar api loaded');
    return api;
  }

  ///
  /// load calendarId from asset file
  static String? _calendarId;
  static const String calendarIdFile = 'assets/google-api/calendar-id.txt';
  static Future<String> defaultCalendarId() async {
    if (_calendarId != null) return Future<String>.value(_calendarId);
    String calendarId = await rootBundle.loadString(calendarIdFile);
    _calendarId = calendarId;
    logger.log('Calendar ID loaded');
    return calendarId;
  }

  static Future<GPS> gps() async {
    loc.Location location = new loc.Location();
    //bool _serviceEnabled;
    //PermissionStatus _permissionGranted;
    loc.LocationData locationData;

    _serviceEnabled = await location.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await location.requestService();
      if (!_serviceEnabled) {
        return;
      }
    }
*/
/*
    _permissionGranted = await location.hasPermission();
    if (_permissionGranted == PermissionStatus.denied) {
      _permissionGranted = await location.requestPermission();
      if (_permissionGranted != PermissionStatus.granted) {
        return;
      }
    }
    locationData = await location.getLocation();
    return GPS(locationData.latitude ?? 0, locationData.longitude ?? 0);
  }
*/
}
