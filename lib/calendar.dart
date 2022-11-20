import 'logger.dart';
import 'package:flutter/services.dart';
import "package:googleapis_auth/auth_io.dart";
import 'package:googleapis/calendar/v3.dart';

class CalendarHandler {
  static const String _calendarId =
      '331f3d4b6cfdd4ba0ed19824ad13fb0c9d457b8b6549122617978cbd0b6116b8@group.calendar.google.com';
  static const String _credentials = 'assets/google-api/service-account.json';

  CalendarHandler();

  void createTestEvent() {
    Event event = Event(
        summary: '<<Android App Test Entry>>',
        start: EventDateTime(
            date: DateTime.now().add(const Duration(minutes: 10))),
        end: EventDateTime(
            date: DateTime.now().add(const Duration(minutes: 60))));
    addEvent(event);
  }

  void addEvent(Event event) {
    _createApi((CalendarApi api) {
      api.events.insert(event, _calendarId).then((value) {
        log('added Event: ${event.summary}');
      }).onError((error, stackTrace) {
        log('add event \'${event.summary}\' failed with ${error.toString()}');
      });
    });
  }

  Future<String> loadCalendarId() {
    return rootBundle.loadString(_calendarId);
  }

  _createApi(Function cb) {
    List<String> scopes = [CalendarApi.calendarScope];
    rootBundle.loadString(_credentials).then((String json) {
      ServiceAccountCredentials credentials =
          ServiceAccountCredentials.fromJson(json);
      clientViaServiceAccount(credentials, scopes)
          .then((AutoRefreshingAuthClient client) {
        cb(CalendarApi(client));
      }).onError((error, stackTrace) =>
              log('create Calendar Client failed with ${error.toString()}'));
    }).onError((error, stackTrace) =>
        log('load Calendar Credentials failed with ${error.toString()}'));
  }
}
