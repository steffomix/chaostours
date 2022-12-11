import 'logger.dart' show log;
import 'config.dart';
import 'address.dart';
import 'dart:async';
import 'locationAlias.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:googleapis_auth/auth_io.dart'
    show
        clientViaServiceAccount,
        ServiceAccountCredentials,
        AutoRefreshingAuthClient;
import 'package:googleapis/calendar/v3.dart'
    show CalendarApi, Event, EventDateTime;
import 'package:crypto/crypto.dart' show sha1;
import 'dart:convert' show utf8;

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

class TrackingCalendar {
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
  late Timer _timer;
  late CalendarApi _api;

  // singelton instance
  static final _handler = TrackingCalendar._init();

  factory TrackingCalendar() => _handler;

  int get status => _currentStatus;

  TrackingCalendar._init() {
    _resetApi();
  }

  String _formatDate(DateTime t) {
    return '${t.day}.${t.month}.${t.year} ${t.hour}:${t.minute}';
  }

  Event createEvent(DateTime start, DateTime end, List<String> tasksList,
      Address addr, String notes) {
    String fStart = _formatDate(start);
    String fEnd = _formatDate(end);
    double lat = addr.lat;
    double lon = addr.lon;
    String url = 'https://maps.google.com?q=$lat,$lon&center=$lat,$lon';
    List<Alias> aliasList = LocationAlias.alias(lat, lon);
    String alias = aliasList.isEmpty ? '' : aliasList[0].alias;
    String address = alias == '' ? addr.asString : '$alias (${addr.asString})';
    List<String> aliasNamesList = [];
    for (var a in aliasList) {
      aliasNamesList.add(a.alias.toUpperCase());
    }
    String aliasNames =
        aliasNamesList.length > 1 ? aliasNamesList.join('; ') : ' - ';

    for (var i = 0; i < tasksList.length; i++) {
      tasksList[i]
        ..replaceAll('\r', '')
        ..replaceAll('\n', '; ');
    }
    List<String> tsvEntryParts = [
      address,
      aliasNames,
      fStart,
      fEnd,
      tasksList.join('; '),
      url
    ];
    String body = 'Ort: $address\r\n'
        'Von $fStart bis $fEnd\r\n\r\n'
        'Arbeiten:\r\n${tasksList.join('\r\n')}\r\n'
        '$notes\r\n\r\n'
        '<a href="$url" target = "_blank">Link zu Google Maps</a>\r\n\r\n'
        'Andere Aliasnamen für diesen Ort: $aliasNames\r\n\r\n'
        'TSV (Tabulator Separated Values) für Excel import:\r\n${tsvEntryParts.join('  ')}';

    body = '$body\r\n\r\n'
        'UUID: ${sha1.convert(utf8.encode('$body ${DateTime.now().microsecondsSinceEpoch}')).toString()}';

    Event e = Event(
        summary: address,
        description: body,
        start: EventDateTime(date: start),
        end: EventDateTime(date: end));
    return e;
  }

  /// add Task(Function) to _queue
  Task addEvent(Event e) {
    Task t = Task(() {
      _api.events.insert(e, _calendarCredentials.calendarId).then((value) {
        _currentStatus = statusReady;
        log('added Event ${e.summary} to calendar');
      }).onError((error, stackTrace) {
        _currentStatus = statusReady;
        log('Add event ${e.summary} to calendar failed: ${error.toString()}');
      });
    });
    _addTask(t);
    return t;
  }

  void _addTask(Task t) {
    if (AppConfig.debugMode) {
      log('TrackingCalendar _addTask skipped due to debug mode');
      return;
    }
    // execute now
    if (_tasks.isEmpty && _currentStatus == statusReady) {
      t.execute();
      return;
    }
    // execute later
    _tasks.add(t);
  }

  void _resetApi() {
    try {
      // Timer may not be set
      _timer.cancel();
    } catch (e) {
      // ignore
    }
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

  void _queue() {
    _timer = Timer(const Duration(seconds: 1), _queue);
    // log('queue status $_currentStatus');
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
