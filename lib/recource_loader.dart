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
import 'package:chaostours/model_alias.dart';
import 'package:chaostours/model_trackpoint.dart';
import 'package:chaostours/model_task.dart';
import 'package:chaostours/log.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/tracking_calendar.dart';
import 'package:chaostours/notifications.dart';

class RecourceLoader {
  ///
  /// preload recources
  static Future<void> preload() async {
    try {
      try {
        var m1 = await ModelAlias.open();
        var m2 = await ModelTrackPoint.open();
        var m3 = await ModelTask.open();
        await Future.delayed(
            const Duration(milliseconds: 200), ModelAlias.write);
        await Future.delayed(
            const Duration(milliseconds: 200), ModelTrackPoint.write);
        await Future.delayed(
            const Duration(milliseconds: 200), ModelTask.write);
      } catch (e) {
        logError(e);
      }
      try {
        if (ModelAlias.length < 1) {
          var ass = await ModelAlias.openFromAsset();
          var y = await Future.delayed(
              const Duration(milliseconds: 200), ModelAlias.write);
        }
      } catch (e) {
        logError(e);
      }

      try {
        if (ModelTask.length < 1) {
          var ass = await ModelTask.openFromAsset();
          var y = await Future.delayed(
              const Duration(milliseconds: 200), ModelTask.write);
        }
      } catch (e) {
        logError(e);
      }

      logInfo('TableAlias ${ModelAlias.length}');
      logInfo('TableTrackPoints ${ModelTrackPoint.length}');
      logInfo('TableTask ${ModelTask.length}');

      TrackingCalendar();
      Notifications().initialize();

      await webKey();
      await defaultCalendarId();
      await calendarApiFromCredentials();
    } catch (e, stk) {
      logFatal('Preload failed', e, stk);
    }
  }

  ///
  /// load ssh key for https connections
  static Future<void> webKey() async {
    ByteData data =
        await PlatformAssetBundle().load('assets/ca/lets-encrypt-r3.pem');
    io.SecurityContext.defaultContext
        .setTrustedCertificatesBytes(data.buffer.asUint8List());
    logInfo('RecourceLoader::WebKey loaded');
  }

  static Future<io.File> fileHandle(String filename) async {
    io.Directory appDir =
        await path_provider.getApplicationDocumentsDirectory();
    //List<String> parts = [appDir.path, ...localPath, filename];
    io.File file = await io.File(path.join(appDir.path, filename)).create();
    return file;
  }

  ///
  /// openStreetMap reverse lookup
  static Future<http.Response> osmReverseLookup(GPS gps) async {
    var url = Uri.https('nominatim.openstreetmap.org', '/reverse',
        {'lat': gps.lat.toString(), 'lon': gps.lon.toString()});
    http.Response response = await http.get(url);
    //logInfo('osmReverseLookup for gps #${gps.id}');
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
    logInfo('RecourceLoader::Calendar api loaded');
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
    logInfo('RecourceLoader::Calendar ID loaded');
    return calendarId;
  }

  static Future<Position> gps() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    Position pos = await Geolocator.getCurrentPosition();
    return pos;
  }
}
