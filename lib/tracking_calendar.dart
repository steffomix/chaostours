import 'log.dart';
import 'dart:async';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'config.dart';
import 'package:chaostours/enum.dart';
import 'track_point.dart';
import 'recource_loader.dart';
import 'util.dart';
import 'events.dart';
import 'package:chaostours/model_trackpoint.dart';
import 'package:chaostours/model_alias.dart';

class TrackingCalendar {
  // singelton
  static StreamSubscription? _trackingStatusListener;
  static final TrackingCalendar _instance = TrackingCalendar._createInstance();
  TrackingCalendar._createInstance() {
    logInfo('addListener');
    _trackingStatusListener ??= eventBusTrackingStatusChanged
        .on<ModelTrackPoint>()
        .listen(onTrackingStatusChanged);
  }
  factory TrackingCalendar() {
    return _instance;
  }

  void onTrackingStatusChanged(ModelTrackPoint event) async {
    if (event.status == TrackingStatus.none) return;
    //logInfo('---- create Event --- $event');
    return;
    try {
      addEvent(await createEvent(event));
    } catch (e, stk) {
      logError('TrackingCalendar::onTrackingStatusChanged', e, stk);
    }
  }

  createEvent(ModelTrackPoint tp) {
    // statusStop = start to stop
    // statusStart = stop to start
    TrackingStatus status = tp.status;

    String duration = timeElapsed(tp.timeStart, tp.timeEnd);

    String fTimeStart = formatDate(tp.timeStart);
    String fTimeStop = formatDate(tp.timeEnd);

    // nearest alias
    String alias = tp.idAlias.isEmpty
        ? ' '
        : ' (${ModelAlias.getAlias(tp.idAlias.first).alias}) ';
    List<String> otherAlias = [];
    if (tp.idAlias.length > 1) {
      for (var i = 1; i < tp.idAlias.length - 1; i++) {
        otherAlias.add(ModelAlias.getAlias(i).alias);
      }
    }
    ModelTrackPoint tpStart = tp.trackPoints.first;
    ModelTrackPoint tpStop = tp.trackPoints.last;

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
        start: calendar.EventDateTime(date: tpStart.timeStart),
        end: calendar.EventDateTime(date: tpStop.timeEnd));
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
