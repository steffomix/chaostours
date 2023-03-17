import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'dart:io' as io;
import 'package:location/location.dart' as loc;
import 'package:permission_handler/permission_handler.dart';

///
import 'package:chaostours/model/model_alias.dart';
import 'package:chaostours/model/model_trackpoint.dart';
import 'package:chaostours/model/model_task.dart';
import 'package:chaostours/model/model_user.dart';
import 'package:chaostours/shared.dart';
import 'package:chaostours/file_handler.dart';
import 'package:chaostours/background_process/tracking.dart';
import 'package:chaostours/background_process/trackpoint.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/background_process/tracking_calendar.dart';
import 'package:chaostours/notifications.dart';
import 'package:chaostours/permissions.dart';
import 'package:chaostours/event_manager.dart';
import 'package:chaostours/logger.dart';
//import 'package:chaostours/background_process/workmanager.dart';
import 'package:chaostours/globals.dart';
import 'package:chaostours/app_settings.dart';

class AppLoader {
  static Logger logger = Logger.logger<AppLoader>();

  ///
  /// preload recources
  static Future<void> preload() async {
    logger.important('start Preload sequence...');

    try {
      logger.important('initialize permissions');
      await Permission.location.request();
      await Permission.locationAlways.request();
      await Permission.storage.request();
      await Permission.manageExternalStorage.request();
      await Permission.notification.request();
      await Permission.calendar.request();
    } catch (e, stk) {
      logger.fatal(
          'app start permissions failure, wait 5 sec. \n${e.toString()}', stk);
      await Future.delayed(const Duration(seconds: 5));
    }
    //logger.important('start background gps tracking');
    //logger.important('initialize workmanager');
    //WorkManager();

    try {
      await AppSettings.loadFromShared();
      await FileHandler().getStorage();

      // load database
      logger.important('load Database Table ModelUser');
      await ModelUser.open();
      logger.important('load Database Table ModelTask');
      await ModelTask.open();
      logger.important('load Database Table ModelAlias');
      await ModelAlias.open();
      logger.important('load Database Table ModelTrackPoint');
      await ModelTrackPoint.open();

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
    } catch (e, stk) {
      logger.fatal(
          'app start database failure, wait 5 sec. \n${e.toString()}', stk);
      await Future.delayed(const Duration(seconds: 5));
    }

    try {
      Shared shared = Shared(SharedKeys.trackPointUp);
      await shared.saveList(<String>[]);
      shared = Shared(SharedKeys.trackPointDown);
      await shared.saveString('');
    } catch (e, stk) {
      logger.error('reset shared data ${e.toString()}', stk);
    }

    try {
      logger.important('preparing HTTP SSL Key');
      await webKey();
      //logger.important('initialize Tracking Calendar');
      //TrackingCalendar();
    } catch (e, stk) {
      logger.fatal(
          'app start calendar failure, wait 5 sec. \n${e.toString()}', stk);
      await Future.delayed(const Duration(seconds: 5));
    }
    /*
      logger.log('load default Calendar ID from assets');
      await defaultCalendarId();
      logger.log('load calendar credentials from assets');
      await calendarApiFromCredentials();
*/

    logger.important('preload finished successful');

    logger.important(
        'start App Tick with ${Globals.appTickDuration}sec. interval');
    Future.microtask(appTick);
    Logger.listenOnTick();

    /// debug only
    //logger.important('start workmanager trackpoint simulation Tick');
    //Future.microtask(workmanagerTick);
/*
    logger.important('initialize background tracker');
    await BackgroundTracking.initialize();
    logger.important('background tracker initialized');
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
    */
  }

  /// debug only
  static Future<void> workmanagerTick() async {
    while (true) {
      try {
        TrackPoint().startShared();
      } catch (e, stk) {
        logger.fatal(e.toString(), stk);
      }
      await Future.delayed(Globals.trackPointInterval);
    }
  }

  static int tick = 0;
  static Future<void> appTick() async {
    while (true) {
      tick++;
      try {
        EventManager.fire<EventOnAppTick>(EventOnAppTick(tick));
      } catch (e, stk) {
        logger.error(e.toString(), stk);
        Logger.print('###### AppTick broke ######');
      }
      await Future.delayed(Globals.appTickDuration);
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

  ///
  /// openStreetMap reverse lookup
  static Future<http.Response> osmReverseLookup(GPS gps) async {
    var url = Uri.https('nominatim.openstreetmap.org', '/reverse',
        {'lat': gps.lat.toString(), 'lon': gps.lon.toString()});
    http.Response response = await http.get(url);
    logger.log('OpenStreetMap reverse lookup for gps #${gps.id} at $gps');
    return response;
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
*/
  static Future<GPS> gps() async {
    loc.Location location = new loc.Location();
    //bool _serviceEnabled;
    //PermissionStatus _permissionGranted;
    loc.LocationData locationData;
/*
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
*/
    locationData = await location.getLocation();
    return GPS(locationData.latitude ?? 0, locationData.longitude ?? 0);
  }
}
