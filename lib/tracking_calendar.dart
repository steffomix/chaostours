import 'log.dart';
import 'dart:async';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:crypto/crypto.dart' show sha1;
import 'dart:convert' show utf8;
import 'config.dart';
import 'gps.dart';
import 'tracking_event.dart';
import 'track_point.dart';
import 'recource_loader.dart';
import 'util.dart';

var x = TrackingCalendar();

class TrackingCalendar {
  // singelton
  static final TrackingCalendar _instance = TrackingCalendar._createInstance();
  TrackingCalendar._createInstance() {
    TrackingStatusChangedEvent.addListener(onTrackingStatusChanged);
  }
  factory TrackingCalendar() {
    return _instance;
  }

  void onTrackingStatusChanged(TrackPoint tp) async {
    try {
      addEvent(await createEvent(tp));
    } catch (e, stk) {
      logError('TrackingCalendar::onTrackingStatusChanged', e, stk);
    }
  }

  createEvent(TrackPoint tp) {
    // statusStop = start to stop
    // statusStart = stop to start

    TrackPoint tpStart = tp.localStatus == TrackingStatus.start
        ? TrackPoint.stoppedAtTrackPoint
        : TrackPoint.startedAtTrackPoint;

    TrackPoint tpStop = tp.localStatus == TrackingStatus.start
        ? TrackPoint.startedAtTrackPoint
        : TrackPoint.stoppedAtTrackPoint;

    String duration = timeElapsed(tpStart.time, tpStop.time);
    num distanceMoved = tp.localStatus == TrackingStatus.start
        ? TrackPoint.idleDistanceMoved.round()
        : (GPS.distance(tpStart.gps, tpStop.gps) / 100).round() / 10;

    String fTimeStart = formatDate(tpStart.time);
    String fTimeStop = formatDate(tpStop.time);

    // nearest alias
    String alias = tp.alias.isEmpty ? '' : '(${tp.alias[0].alias})';
    List<String> otherAlias = [];
    if (tp.alias.length > 1) {
      for (var i = 1; i < tp.alias.length - 1; i++) {
        otherAlias.add(tp.alias[i].alias);
      }
    }

    String summary = tp.localStatus == TrackingStatus.start
        ? '##STOP## $duration Stand bei: ${tpStart.address.asString}'
        : '##START## $duration, ${distanceMoved}km Fahrt von: ${tpStop.address.asString} bis ${tpStart.address.asString}';

    String body = 'Von $fTimeStop bis $fTimeStart\n$summary';

    logInfo('Calender Event: $body');
    calendar.Event e = calendar.Event(
        summary: summary,
        description: body,
        start: calendar.EventDateTime(date: tpStart.time),
        end: calendar.EventDateTime(date: tpStop.time));
    return Future<calendar.Event>.value(e);
    //
  }

  Future<calendar.Event> _createEvent(TrackPoint tp) async {
    bool start = TrackPoint.status == TrackingStatus.start;
    TrackPoint stopped = TrackPoint.stoppedAtTrackPoint;
    TrackPoint started = TrackPoint.startedAtTrackPoint;
    String time = start
        ? timeElapsed(tp.time, stopped.time)
        : timeElapsed(tp.time, started.time);
    int distanceMoved = start ? 0 : TrackPoint.distanceMoved.round();

    DateTime tStart = tp.time;
    DateTime tStop = start ? stopped.time : started.time;
    String fStart = formatDate(tStart);
    String fEnd = formatDate(tStop);
    List<String> tasks = ['schindern', 'malochen', 'knechten', 'rackern'];
    String message = 'Von $fStart bis $fEnd\n';
    message += start ? 'Start von' : 'Stop bei';
    message += ' ${tp.address.asString} \n';
    message += 'um $fStart ';
    message += start ? 'nach $time' : 'nach ${distanceMoved / 1000}km in $time';

    double lat = tp.gps.lat;
    double lon = tp.gps.lon;
    String url = 'https://maps.google.com?q=$lat,$lon&center=$lat,$lon';
    String alias = tp.alias.isEmpty ? '' : tp.alias[0].alias;
    String address =
        alias == '' ? tp.address.asString : '$alias (${tp.address.asString})';
    List<String> aliasNamesList = [];
    for (var a in tp.alias) {
      aliasNamesList.add(a.alias.toUpperCase());
    }
    String aliasNames =
        aliasNamesList.length > 1 ? aliasNamesList.join('; ') : ' - ';

    for (var i = 0; i < tasks.length; i++) {
      tasks[i]
        ..replaceAll('\r', '')
        ..replaceAll('\n', '; ');
    }
    List<String> tsvEntryParts = [
      address,
      aliasNames,
      fStart,
      fEnd,
      tasks.join('; '),
      url
    ];
    String notes = '';
    String body = 'Ort: $address\n'
        'Von $fStart bis $fEnd\n\n'
        'Arbeiten:\n${tasks.join('\n')}\n'
        'Notizen: ${notes == '' ? '-' : notes}\n\n'
        '<a href="$url" target = "_blank">Link zu Google Maps</a>\n\n'
        'Andere Aliasnamen für diesen Ort: $aliasNames\n\n'
        'TSV (Tabulator Separated Values) für Excel import:\n${tsvEntryParts.join('  ')}';

    body = '$body\n\n'
        'UUID: ${sha1.convert(utf8.encode('$body ${DateTime.now().microsecondsSinceEpoch}')).toString()}';
    logInfo('created Calendar Event: $fStart - $fEnd\n $address\n$body');
    calendar.Event e = calendar.Event(
        summary: address,
        description: body,
        start: calendar.EventDateTime(date: tStart),
        end: calendar.EventDateTime(date: tStop));
    return Future<calendar.Event>.value(e);
  }

  /// send event with calendar api
  Future<calendar.Event> addEvent(calendar.Event event) async {
    String id = await RecourceLoader.defaultCalendarId();
    calendar.CalendarApi api =
        await RecourceLoader.calendarApiFromCredentials();
    if (AppConfig.debugMode) {
      logFatal('Skip send Calendar Event due to debug mode: ${event.summary}');
      return event;
    } else {
      calendar.Event send = await api.events.insert(event, id);
      return send;
    }
  }
}
