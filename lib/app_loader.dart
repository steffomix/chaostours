import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
//import 'package:googleapis_auth/auth_io.dart';
//import 'package:googleapis/calendar/v3.dart' show CalendarApi;
import 'package:geolocator/geolocator.dart'
    show Position, LocationPermission, Geolocator;
import 'dart:io' as io;
//
import 'package:chaostours/model/model_alias.dart';
import 'package:chaostours/model/model_trackpoint.dart';
import 'package:chaostours/model/model_task.dart';
import 'package:chaostours/shared/shared.dart';
import 'package:chaostours/shared/shared_tracker.dart';
import 'package:chaostours/shared/tracking.dart';
import 'package:chaostours/trackpoint.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/tracking_calendar.dart';
import 'package:chaostours/notifications.dart';
import 'package:chaostours/permissions.dart';
import 'package:chaostours/event_manager.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/workmanager.dart';

class AppLoader {
  static Logger logger = Logger.logger<AppLoader>();

  ///
  /// preload recources
  static Future<void> preload() async {
    logger.important('start Preload sequence...');

    Shared sharedAlias = Shared(SharedKeys.modelAlias);
    sharedAlias.saveList([]);
    //logger.important('start background gps tracking');
    //logger.important('initialize workmanager');
    WorkManager();

    //await Tracking.initialize();
    //await Tracking.startTracking();
    try {
      try {
        // load database
        logger.important('load Database Table ModelTrackPoint');
        await ModelTrackPoint.open();
        logger.important('load Database Table ModelAlias');
        await ModelAlias.open();
        logger.important('load Database Table ModelTask');
        await ModelTask.open();
        if (ModelAlias.length < 1) {
          await ModelAlias.openFromAsset();
        }
        if (ModelTask.length < 1) {
          await ModelTask.openFromAsset();
        }
      } catch (e, stk) {
        logger.fatal(e.toString(), stk);
      }

      // init Machines
      //logger.important('initialize Tracking Calendar');
      //TrackingCalendar();
      logger.important('initialize Notifications');
      Notifications();
      logger.important('initialize Trackpoint');
      TrackPoint();
      logger.important('initialize SharedTracker');
      SharedTracker();
      logger.important('initialize Permissions');

      logger.important('preparing HTTP SSL Key');
      await webKey();
      /*
      logger.log('load default Calendar ID from assets');
      await defaultCalendarId();
      logger.log('load calendar credentials from assets');
      await calendarApiFromCredentials();
*/

      logger.important('preload finished successful');

      Logger.listenOnTick();
      logger.important('start App Tick with 1sec. interval');
      Future.microtask(appTick);

      logger.important('start workmanager simulation Tick');
      Future.microtask(workmanagerTick);
    } catch (e, stk) {
      logger.fatal('Preload sequence failed: $e', stk);
    }
  }

  static Future<void> workmanagerTick() async {
    await TrackPoint.initializeShared();
    while (true) {
      try {
        TrackPoint.startShared();
      } catch (e, stk) {
        logger.fatal(e.toString(), stk);
      }
      await Future.delayed(const Duration(seconds: 20));
    }
  }

  static int tick = 0;
  static Future<void> appTick() async {
    while (true) {
      tick++;
      try {
        print('Tick #$tick');
        EventManager.fire<EventOnTick>(EventOnTick());
        //logger.log('Tick #$tick');
      } catch (e) {
        print('appTick failed: $e');
      } finally {
        Logger.print('###### AppTick broke ######');
      }
      await Future.delayed(const Duration(seconds: 1));
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
  static Future<Position> gps() async {
    bool serviceEnabled;
    LocationPermission permission;
    String msg;
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      msg = 'Location services are disabled.';
      logger.error(msg, null);
      return Future.error(msg);
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        msg = 'Location permissions are denied';
        logger.error(msg, null);
        return Future.error(msg);
      }
    }

    if (permission == LocationPermission.deniedForever) {
      msg = 'Location permissions are permanently denied, '
          'we cannot request permissions.';
      logger.error(msg, null);
      return Future.error(msg);
    }
    Position pos = await Geolocator.getCurrentPosition();
    return pos;
  }
}
