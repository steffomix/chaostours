import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:googleapis/calendar/v3.dart' show CalendarApi;
import 'package:geolocator/geolocator.dart'
    show Position, LocationPermission, Geolocator;
import 'dart:io' as io;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart' as path_provider;
//
import 'package:chaostours/model/model_alias.dart';
import 'package:chaostours/model/model_trackpoint.dart';
import 'package:chaostours/model/model_task.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/tracking_calendar.dart';
import 'package:chaostours/notifications.dart';
import 'package:chaostours/shared_model/shared.dart';
import 'package:chaostours/event_manager.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/events.dart';

class AppLoader {
  static Logger logger = Logger.logger<AppLoader>();

  ///
  /// preload recources
  static Future<void> preload() async {
    logger.log('start Preload sequence...');
    try {
      // load database
      logger.log('load Database Table ModelTrackPoint');
      await ModelTrackPoint.open();
      logger.log('load Database Table ModelAlias');
      await ModelAlias.open();
      logger.log('load Database Table ModelTask');
      await ModelTask.open();
      if (ModelAlias.length < 1) {
        await ModelAlias.openFromAsset();
      }
      if (ModelTask.length < 1) {
        await ModelTask.openFromAsset();
      }

      // init Machines
      logger.log('initialize Tracking Calendar');
      TrackingCalendar();
      logger.log('initialize Notifications');
      Notifications();

      logger.log('preparing HTTP SSL Key');
      await webKey();
      logger.log('load default Calendar ID from assets');
      await defaultCalendarId();
      logger.log('load calendar credentials from assets');
      await calendarApiFromCredentials();
    } catch (e, stk) {
      logger.fatal('Preload sequence failed: $e', stk);
    }

    logger.log('start shared observer for backgroundGPS with 1sec. interval');
    Shared(SharedKeys.backgroundGps).observe(
        duration: const Duration(seconds: 1),
        fn: (String data) {
          List<String> geo = data.split(',');
          double lat = double.parse(geo[0]);
          double lon = double.parse(geo[1]);
          EventManager.fire<EventOnGps>(EventOnGps(GPS(lat, lon)));
        });
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

  static Future<io.File> fileHandle(String filename) async {
    io.Directory appDir =
        await path_provider.getApplicationDocumentsDirectory();
    String p = path.join(appDir.path, /*'chaostours',*/ filename);
    io.File file = await io.File(p).create();
    logger.log('file handle created for file: $p');
    return file;
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

  static Future<Position> gps() async {
    bool serviceEnabled;
    LocationPermission permission;
    String msg;
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      msg = 'Location services are disabled.';
      logger.warn(msg);
      return Future.error(msg);
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        msg = 'Location permissions are denied';
        logger.warn(msg);
        return Future.error(msg);
      }
    }

    if (permission == LocationPermission.deniedForever) {
      msg = 'Location permissions are permanently denied, '
          'we cannot request permissions.';
      logger.warn(msg);
      return Future.error(msg);
    }
    logger.log('request GPS ${!serviceEnabled ? 'anyway' : ''}');
    Position pos = await Geolocator.getCurrentPosition();
    return pos;
  }
}
