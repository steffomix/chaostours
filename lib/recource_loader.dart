import 'log.dart';
import 'gps.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:googleapis/calendar/v3.dart' show CalendarApi;
import 'package:geolocator/geolocator.dart'
    show Position, LocationPermission, Geolocator;
import 'location_alias.dart';

class RecourceLoader {
  ///
  /// preload recources
  static Future<void> preload() async {
    try {
      await webKey();
      await locationAlias();
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
    SecurityContext.defaultContext
        .setTrustedCertificatesBytes(data.buffer.asUint8List());
    logInfo('RecourceLoader::WebKey loaded');
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
  ///
  static String? _locationAlias;

  ///
  static Future<String> locationAlias() async {
    if (_locationAlias != null) return Future<String>.value(_locationAlias);
    String alias = await rootBundle.loadString('assets/locationAlias.tsv');
    _locationAlias = alias;
    LocationAlias.loadeAliasList();
    logInfo('RecourceLoader::locationAlias loaded');
    return alias;
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
