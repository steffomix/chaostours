import 'log.dart';
import 'dart:async';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'config.dart';
import 'track_point.dart';
import 'recource_loader.dart';
import 'util.dart';
import 'events.dart';

class TrackingCalendar {
  // singelton
  static StreamSubscription? _trackingStatusListener;
  static final TrackingCalendar _instance = TrackingCalendar._createInstance();
  TrackingCalendar._createInstance() {
    logInfo('addListener');
    _trackingStatusListener ??= trackingStatusChangedEvents
        .on<TrackPointEvent>()
        .listen(onTrackingStatusChanged);
  }
  factory TrackingCalendar() {
    return _instance;
  }

  void onTrackingStatusChanged(TrackPointEvent event) async {
    try {
      addEvent(await createEvent(event));
    } catch (e, stk) {
      logError('TrackingCalendar::onTrackingStatusChanged', e, stk);
    }
  }

  createEvent(TrackPointEvent event) {
    // statusStop = start to stop
    // statusStart = stop to start
    TrackPoint tp = event.trackList.last;
    TrackingStatus status = event.status;

    TrackPoint tpStart =
        status == TrackingStatus.moving ? event.stopped : event.started;

    TrackPoint tpStop =
        status == TrackingStatus.moving ? event.started : event.stopped;

    String duration = timeElapsed(tpStart.time, tpStop.time);

    String fTimeStart = formatDate(tpStart.time);
    String fTimeStop = formatDate(tpStop.time);

    // nearest alias
    String alias = tp.alias.isEmpty ? ' ' : ' (${tp.alias[0].alias}) ';
    List<String> otherAlias = [];
    if (tp.alias.length > 1) {
      for (var i = 1; i < tp.alias.length - 1; i++) {
        otherAlias.add(tp.alias[i].alias);
      }
    }

    String summary = status == TrackingStatus.moving
        ? '##STOP## $duration Stand bei:$alias${tpStart.address.asString}'
        : '##START## $duration, ?Calc Distance?km Fahrt von: ${tpStop.address.asString} bis ${tpStart.address.asString}';

    String body = 'Von $fTimeStop bis $fTimeStart\n$summary\n\n'
        'Andere Aliasnamen:'
        '${otherAlias.isNotEmpty ? '\n${otherAlias.join('\n')}' : ' - '}';

    //logInfo('Calender Event: $body');
    calendar.Event e = calendar.Event(
        summary: summary,
        description: body,
        start: calendar.EventDateTime(date: tpStart.time),
        end: calendar.EventDateTime(date: tpStop.time));
    return Future<calendar.Event>.value(e);
    //
  }

  /// send event with calendar api
  Future<calendar.Event> addEvent(calendar.Event event) async {
    String id = await RecourceLoader.defaultCalendarId();
    calendar.CalendarApi api =
        await RecourceLoader.calendarApiFromCredentials();
    if (AppConfig.debugMode) {
      //logFatal('Skip send Calendar Event due to debug mode: ${event.summary}');
      return event;
    } else {
      calendar.Event send = await api.events.insert(event, id);
      return send;
    }
  }
}
