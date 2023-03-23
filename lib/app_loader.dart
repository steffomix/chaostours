import 'package:flutter/services.dart';
import 'dart:io' as io;
import 'package:permission_handler/permission_handler.dart';

///
import 'package:chaostours/model/model_alias.dart';
import 'package:chaostours/model/model_trackpoint.dart';
import 'package:chaostours/model/model_task.dart';
import 'package:chaostours/model/model_user.dart';
import 'package:chaostours/file_handler.dart';
import 'package:chaostours/background_process/tracking.dart';
import 'package:chaostours/shared.dart';
import 'package:chaostours/event_manager.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/permission_checker.dart';
import 'package:chaostours/globals.dart';
import 'package:chaostours/app_settings.dart';

class AppLoader {
  static Logger logger = Logger.logger<AppLoader>();

  static bool appLoaderPreloadSequenceFinished = false;
  static bool appLoaderWebKeyLoaded = false;
  static bool appLoaderSharedSettingsLoaded = false;
  static bool appLoaderStorageInitialized = false;
  static bool appLoaderDatabseLoaded = false;
  static bool appLoaderAssetDatabaseLoaded = false;
  static bool appLoaderPermissionsRequested = false;
  static bool appLoaderTicksStarted = false;

  ///
  /// preload recources
  static Future<void> preload() async {
    logger.important('start Preload sequence...');
    try {
      await PermissionChecker.requestAll();
      await webKey();
      await loadSharedSettings();
      await initializeStorages();
      await loadDatabase();
      await loadAssetDatabase();
      await ticks();
      await backgroundGps();
      appLoaderPreloadSequenceFinished = true;
    } catch (e, std) {
      logger.fatal('Startup sequence failed: ${e.toString()}', std);
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
    appLoaderWebKeyLoaded = true;
  }

  static Future<void> loadSharedSettings() async {
    await AppSettings.loadFromShared();
    appLoaderSharedSettingsLoaded = true;
  }

  static Future<void> initializeStorages() async {
    logger.important('initialize storages');
    await FileHandler().getStorage();
    appLoaderStorageInitialized = true;
  }

  static Future<void> loadDatabase() async {
    if (PermissionChecker.permissionsChecked &&
        PermissionChecker.permissionsOk &&
        FileHandler.storagePath != null) {
      // load database
      logger.important('load Database Table ModelUser');
      await ModelUser.open();
      logger.important('load Database Table ModelTask');
      await ModelTask.open();
      logger.important('load Database Table ModelAlias');
      await ModelAlias.open();
      logger.important('load Database Table ModelTrackPoint');
      await ModelTrackPoint.open();
      appLoaderDatabseLoaded = true;
    }
  }

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
    appLoaderAssetDatabaseLoaded = true;
  }

  static Future<void> ticks() async {
    logger.important('start app-tick');
    SharedLoader.instance.listen();
    _appTick();
    _addressTick();
    logger.important('logger listen on app-tick ready');
    Logger.listenOnTick();
    appLoaderTicksStarted = true;
  }

  static Future<void> backgroundGps() async {
    logger.important('initialize background tracker');
    await BackgroundTracking.initialize();
    logger.important('background tracker initialized');

    if (Globals.backgroundTrackingEnabled) {
      logger.important('Start background tracker');
      await BackgroundTracking.startTracking();

      bool started = await BackgroundTracking.isTracking();
      if (started) {
        logger.important('Background tracker started');
      } else {
        try {
          throw 'Background tracker failed starting';
        } catch (e, stk) {
          logger.fatal(e.toString(), stk);
        }
      }
    } else {
      logger.important('stopping background gps');
      BackgroundTracking.stopTracking();
    }
  }

  static Future<void> _appTick() async {
    while (true) {
      var event = EventOnAppTick();
      try {
        EventManager.fire<EventOnAppTick>(event);
      } catch (e, stk) {
        logger.error('appTick #${event.id} failed: ${e.toString()}', stk);
      }
      await Future.delayed(Globals.appTickDuration);
    }
  }

  static Future<void> _addressTick() async {
    while (true) {
      var event = EventOnAddressLookup();
      try {
        if (Globals.osmLookupInterval.inSeconds > 10) {
          EventManager.fire<EventOnAddressLookup>(event);
        }
      } catch (e, stk) {
        logger.error('appTick #${event.eventId} failed: ${e.toString()}', stk);
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
