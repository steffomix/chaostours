/*
import 'dart:async';
import 'package:googleapis/calendar/v3.dart' as calendar;
//
import 'package:chaostours/app_loader.dart';
import 'package:chaostours/util.dart';
import 'package:chaostours/model/model_trackpoint.dart';
import 'package:chaostours/model/model_alias.dart';
import 'package:chaostours/model/model_task.dart';
import 'package:chaostours/globals.dart';
import 'package:chaostours/trackpoint.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/event_manager.dart';

class TrackingCalendar {
  static final Logger logger = Logger.logger<TrackingCalendar>();
  // singelton
  static TrackingCalendar? _instance;
  TrackingCalendar._() {
    EventManager.listen<EventOnTrackingStatusChanged>(onTrackingStatusChanged);
  }
  factory TrackingCalendar() => _instance ??= TrackingCalendar._();

  void onTrackingStatusChanged(EventOnTrackingStatusChanged event) async {
    ModelTrackPoint tp = event.tp;
    if (tp.status == TrackingStatus.none) return;
    //logInfo('---- create Event --- $event');
    //return;
    try {
      addEvent(await createEvent(tp));
    } catch (e, stk) {
      logger.error('$e', stk);
    }
  }

  createEvent(ModelTrackPoint tp) async {
    logger.log('create Event from ModelTrackPoint ID #${tp.id}');
    // statusStop = start to stop
    // statusStart = stop to start
    TrackingStatus status = tp.status;

    String duration = tp.timeElapsed();
    double distance = tp.distance();

    double lat = tp.gps.lat;
    double lon = tp.gps.lon;

    String address = tp.address.asString;

    String fTimeStart = formatDate(tp.timeStart);
    String fTimeEnd = formatDate(tp.timeEnd);

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

    String body = '$summary\n(Von $fTimeStart bis $fTimeEnd)\n\n';

    String tasks = 'Erledigte Aufgaben (${tp.idTask.length}):\n';
    for (var t in tp.idTask) {
      tasks += '- ${ModelTask.getTask(t).task}\n';
    }
    body += '\n$tasks\n\n<hr>\n';
    String move = 'GPS route (save to file and upload at '
        '<a href="https://www.gpsvisualizer.com">gpsvisualizer.com</a>\n\n'
        'latitude,longitude\n';
    for (var t in tp.trackPoints) {
      move += '${t.lat},${t.lon}\n';
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

    return await Future<calendar.Event>.value(e);
    //
  }

  /// send event with calendar api
  Future<calendar.Event> addEvent(calendar.Event event) async {
    logger.log('sending "${event.summary}"...');
    String id = await AppLoader.defaultCalendarId();
    calendar.CalendarApi api = await AppLoader.calendarApiFromCredentials();
    if (Globals.debugMode) {
      logger.warn(
          'Skip send Calendar Event due to Globals.debugMode=true:\n ${event.summary}');
      return event;
    } else {
      try {
        await api.events.insert(event, id);
      } catch (e, stk) {
        logger.error('addEvent failed: $e', stk);
      }
      return event;
    }
  }
}
*/