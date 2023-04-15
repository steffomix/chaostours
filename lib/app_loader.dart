import 'package:flutter/services.dart';
import 'dart:io' as io;

///
import 'package:chaostours/model/model_alias.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/model/model_trackpoint.dart';
import 'package:chaostours/model/model_task.dart';
import 'package:chaostours/model/model_user.dart';
import 'package:chaostours/file_handler.dart';
import 'package:chaostours/background_process/tracking.dart';
import 'package:chaostours/event_manager.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/permission_checker.dart';
import 'package:chaostours/globals.dart';
import 'package:chaostours/data_bridge.dart';

class AppLoader {
  static Logger logger = Logger.logger<AppLoader>();

  ///
  /// preload recources
  static Future<void> preload() async {
    logger.important('start Preload sequence...');
    await webKey();
    await globalSettings();
    await loadDatabase();
    try {
      if (FileHandler.storagePath != null) {
        await loadDatabase();
      } else {}
      await PermissionChecker.checkAll();
      if (PermissionChecker.permissionsOk) {
        try {
          GPS gps = await GPS.gps();
          await DataBridge.instance.loadBackground(gps);
          await DataBridge.instance.loadForeground(gps);
          await DataBridge.instance.saveBackground(gps);
        } catch (e) {
          logger.warn('preload gps not available');
        }
        await FileHandler.getPotentialStorages();
        //await initializeStorages();
        await ticks();
      }
    } catch (e, std) {
      logger.fatal('Startup sequence failed: ${e.toString()}', std);
    }
  }

  static Future<void> loadCache() async {
    GPS gps = await GPS.gps();
    await DataBridge.instance.loadBackground(gps);
    await DataBridge.instance.loadForeground(gps);
    await DataBridge.instance.saveBackground(gps);
  }

  static Future<void> storageSettings() async {
    await FileHandler.getPotentialStorages();
    await FileHandler.loadSettings();
    await FileHandler.saveSettings();
  }

  static Future<void> globalSettings() async {
    await Globals.loadSettings();
    await Globals.saveSettings();
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

  static Future<bool> loadDatabase() async {
    if (await PermissionChecker.checkManageExternalStorage() &&
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
      return true;
    }
    return false;
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
    logger.important('start app-tick');
    DataBridge.instance.startService();
    _appTick();
    _addressTick();
    logger.important('logger listen on app-tick ready');
    Logger.listenOnTick();
  }

  static Future<void> backgroundGps() async {
    if (Globals.backgroundTrackingEnabled) {
      await BackgroundTracking.startTracking();
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
        if (Globals.osmLookupInterval.inMinutes > 0) {
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
