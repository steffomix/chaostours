import 'dart:async';
import 'geoCoding.dart';
import 'logger.dart';
import 'package:flutter/services.dart';
import "package:googleapis_auth/auth_io.dart";
import 'package:googleapis/calendar/v3.dart';

class Task {
  final statusQueue = 0;
  final statusPending = 1;
  final statusExecuted = 2;
  final statusError = 3;
  int _status = 0;
  final Function _t;
  Task(this._t);
  Task execute() {
    _t();
    _status = statusPending;
    return this;
  }

  get status {
    return _status;
  }
}

class CalendarHandler {
  final int statusDamaged = 3;
  final int statusInitializing = 2;
  final int statusBusy = 1;
  final int statusReady = 0;
  int _currentStatus = 2;

  final List<String> scopes = [CalendarApi.calendarScope];
  final String calendarIdFile = 'assets/google-api/calendar-id.txt';
  final String credentialsFile = 'assets/google-api/service-account.json';

  CalendarCredentials _calendarCredentials = CalendarCredentials.blank();

  final List<Task> _tasks = [];
  //late Timer _t = Timer(const Duration(seconds: 1), _queue);
  late CalendarApi _api;

  // singelton instance
  static final _handler = CalendarHandler._init();

  factory CalendarHandler() => _handler;

  CalendarHandler._init() {
    _resetApi();
  }

  /// add Task(Function) to _queue
  Task addEvent(
      String title, String description, List<String> tasks, Address position) {
    Event e = Event(
        summary: '<<Android App Test Entry>>',
        start: EventDateTime(
            date: DateTime.now().add(const Duration(minutes: 10))),
        end: EventDateTime(
            date: DateTime.now().add(const Duration(minutes: 60))));
    Task t = Task(() {
      _api.events.insert(e, _calendarCredentials.calendarId).then((value) {
        _currentStatus = statusReady;
        log('added Event ${e.summary} to calendar');
      }).onError((error, stackTrace) {
        _currentStatus = statusReady;
        log('Add event ${e.summary} to calendar failed: ${error.toString()}');
      });
    });
    // execute now
    if (_tasks.isEmpty && _currentStatus == statusReady) return t.execute();
    // execute later
    _tasks.add(t);
    return t;
  }

  void _resetApi() {
    log('reset api');
    _currentStatus = statusInitializing;
    _calendarCredentials = CalendarCredentials.blank();
    _createApi();
  }

  void _ready() {
    log('Calendar Api ready');
    _currentStatus = statusReady;
    _queue();
    // _t = Timer(const Duration(seconds: 1), _queue);
  }

  int get status {
    return _currentStatus;
  }

  void _queue() {
    Timer(const Duration(seconds: 1), _queue);
    log('queue status $_currentStatus');
    if (_currentStatus > 0) {
      log('Queue Calendar Api failed due to Status $_currentStatus');
      return;
    }
    if (_tasks.isEmpty) return;
    _currentStatus = statusBusy;
    _tasks.removeAt(0).execute();
  }

  void _createApi() {
    rootBundle.loadString(calendarIdFile).then((String calendarId) {
      // load credentials
      rootBundle.loadString(credentialsFile).then((String jsonString) {
        // remember loaded files
        _calendarCredentials = CalendarCredentials(calendarId, jsonString);
        // create client with on-the-fly created credential object
        clientViaServiceAccount(
                ServiceAccountCredentials.fromJson(jsonString), scopes)
            .then((AutoRefreshingAuthClient client) {
          // finally create api
          _api = CalendarApi(client);
          _ready();
          // do some oops!
        }).onError((error, stackTrace) {
          _currentStatus = statusDamaged;
          log('create Calendar Client failed with ${error.toString()}');
        });
      }).onError((error, stackTrace) {
        _currentStatus = statusDamaged;
        log('load Calendar Credentials failed with ${error.toString()}');
      });
    }).onError((error, stackTrace) {
      _currentStatus = statusDamaged;
      log('load calendar id failed with ${error.toString()}');
    });
  }
}

/// stores loaded credentials
class CalendarCredentials {
  final String calendarId;
  final String jsonString;

  late String test;

  bool _isBlank = true;

  CalendarCredentials(this.calendarId, this.jsonString) {
    _isBlank = false;
  }

  get isBlank {
    return _isBlank;
  }

  CalendarCredentials.blank()
      : calendarId = '',
        jsonString = '';
}
