import 'log.dart';
import 'dart:async';
import 'package:googleapis/calendar/v3.dart' as calendar;
//
import 'package:chaostours/recource_loader.dart';
import 'package:chaostours/util.dart';
import 'package:chaostours/events.dart';
import 'package:chaostours/model_trackpoint.dart';
import 'package:chaostours/model_alias.dart';
import 'package:chaostours/model_task.dart';
import 'package:chaostours/globals.dart';
import 'package:chaostours/enum.dart';

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
    //return;
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

    String duration = tp.timeElapsed();
    double distance = tp.distance();

    double lat = tp.gps.lat;
    double lon = tp.gps.lon;

    String address = tp.address.asString;

    String fTimeStart = formatDate(tp.timeStart);
    String fTimeStop = formatDate(tp.timeEnd);

    // nearest alias
    String alias = tp.idAlias.isEmpty
        ? '<a href="https://maps.google.com&q=$lat,$lon&center=$lat,$lon">$address</a>'
        : ' (${ModelAlias.getAlias(tp.idAlias.first).alias}) ';
    /*
    List<String> otherAlias = [];
    if (tp.idAlias.length > 1) {
      for (var i = 1; i < tp.idAlias.length - 1; i++) {
        otherAlias.add(ModelAlias.getAlias(i).alias);
      }
    }
    */
    String summary = '';
    if (status == TrackingStatus.moving) {
      summary += '$duration bei $alias';
    } else {
      summary += '${distance}km Fahrt in $duration';
    }

    String body = '$summary\n\n';

    String tasks = 'Tasks (${tp.idTask.length}):\n';
    for (var t in tp.idTask) {
      tasks += '- ${ModelTask.getTask(t).task}\n';
    }
    body += '\n$tasks';
    String move = 'GPS route (save to file and upload at '
        '<a href="https://www.gpsvisualizer.com">gpsvisualizer.com</a>\n\n'
        'latitude,longitude\n';
    for (var t in tp.trackPoints) {
      move += '${t.gps.lat},${t.gps.lon}\n';
    }

    body += move;

    if (status == TrackingStatus.moving) {}
    //logInfo('Calender Event: $body');
    calendar.Event e = calendar.Event(
        summary: summary,
        description: body,
        start: calendar.EventDateTime(dateTime: tp.timeStart),
        end: calendar.EventDateTime(dateTime: tp.timeEnd));
    e.colorId = status == TrackingStatus.standing ? '1' : '4';
    e.location = '$lat,$lon';

    logInfo('Calendar:\n$summary\n$body');
    return Future<calendar.Event>.value(e);
    //
  }

  /// send event with calendar api
  Future<calendar.Event> addEvent(calendar.Event event) async {
    String id = await RecourceLoader.defaultCalendarId();
    calendar.CalendarApi api =
        await RecourceLoader.calendarApiFromCredentials();
    if (!Globals.debugMode) {
      //logFatal('Skip send Calendar Event due to debug mode: ${event.summary}');
      return event;
    } else {
      calendar.Event send = await api.events.insert(event, id);
      return send;
    }
  }
}
