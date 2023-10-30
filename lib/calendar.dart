/*
Copyright 2023 Stefan Brinkmann <st.brinkmann@gmail.com>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

import 'package:chaostours/conf/app_settings.dart';
import 'package:chaostours/model/model_alias_group.dart';
import 'package:device_calendar/device_calendar.dart';

///
import 'package:chaostours/logger.dart';
import 'package:chaostours/cache.dart';
import 'package:chaostours/data_bridge.dart';
import 'package:chaostours/trackpoint_data.dart';

class CalendarEventId {
  String calendarId;
  String eventId;
  static const String separator = ',';

  CalendarEventId({this.calendarId = '', this.eventId = ''});

  @override
  String toString() {
    return '$calendarId$separator$eventId';
  }

  static CalendarEventId toObject(String s) {
    var parts = s.split(separator);
    if (parts.length == 2) {
      return CalendarEventId(calendarId: parts[0], eventId: parts[1]);
    }
    return CalendarEventId(eventId: s);
  }
}

class AppCalendar {
  static final Logger logger = Logger.logger<AppCalendar>();

  final DeviceCalendarPlugin _deviceCalendarPlugin = DeviceCalendarPlugin();
  final bridge = DataBridge.instance;

  Future<String?> inserOrUpdate(Event e) async {
    Result<String>? id = await _deviceCalendarPlugin.createOrUpdateEvent(e);
    return id?.data;
  }

  Future<List<Event?>> getEventsById(
      {required String calendarId, required String eventId}) async {
    var params = RetrieveEventsParams(eventIds: [eventId]);
    var events = await _deviceCalendarPlugin.retrieveEvents(calendarId, params);
    return events.data ?? <Event>[];
  }

  Future<List<Calendar>> loadCalendars() async {
    var calendars = <Calendar>[];
    try {
      var permissionsGranted = await _deviceCalendarPlugin.hasPermissions();
      if (permissionsGranted.isSuccess &&
          (permissionsGranted.data == null ||
              permissionsGranted.data == false)) {
        permissionsGranted = await _deviceCalendarPlugin.requestPermissions();
        if (!permissionsGranted.isSuccess ||
            permissionsGranted.data == null ||
            permissionsGranted.data == false) {
          var msg = 'No Calendar access permission granted by User';
          logger.fatal(msg, StackTrace.current);
          throw msg;
        }
      }

      final calendarsResult = await _deviceCalendarPlugin.retrieveCalendars();
      if (calendarsResult.hasErrors) {
        List<String> err = [];
        calendarsResult.errors.map((e) {
          err.add(e.errorMessage);
        });
        DataBridge.instance.trackPointUserNotes = await Cache.setValue<String>(
            CacheKeys.cacheBackgroundTrackPointUserNotes, err.join('\n\n'));
      }
      var data = calendarsResult.data;
      if (data != null) {
        calendars.addAll(data);
      }
    } catch (e, stk) {
      logger.error('retrieve calendars: $e', stk);
    }

    return calendars;
  }

  Future<Calendar?> calendarById(String id) async {
    var calendars = await loadCalendars();
    try {
      for (var c in calendars) {
        if (c.id == id) {
          return c;
        }
      }
    } catch (e, stk) {
      logger.error('getCalendarFromCacheId: $e', stk);
    }
    return null;
  }

  Future<void> startCalendarEvent(TrackPointData tpData) async {
    var calendars = await loadCalendars();
    if (calendars.isNotEmpty) {
      /// get dates
      final berlin = getLocation(AppSettings.timeZone);
      var start = TZDateTime.from(tpData.timeStart, berlin);
      var end = start.add(const Duration(minutes: 2));

      var title =
          'Ankunft ${tpData.aliasModels.isNotEmpty ? tpData.aliasModels.first.title : tpData.addressText} - ${start.hour}.${start.minute}';
      var location =
          'maps.google.com?q=${tpData.gpslastStatusChange.lat},${tpData.gpslastStatusChange.lon}';
      var description =
          '${tpData.aliasModels.isNotEmpty ? tpData.aliasModels.first.title : tpData.addressText}\n'
          'am ${start.day}.${start.month}.${start.year}\n'
          'um ${start.hour}.${start.minute} - unbekannt)\n\n'
          'Arbeiten: ...\n\n'
          'Mitarbeiter:\n${tpData.usersText}\n\n'
          'Notizen: ...';

      var groups = await ModelAliasGroup.aliasGroups(tpData.aliasModels);
      Set calIds = groups
          .map(
            (e) => e.idCalendar,
          )
          .toSet();
      List<CalendarEventId> newEvents = [];
      for (var calId in calIds) {
        Calendar? calendar = await calendarById(calId);
        if (calendar == null) {
          logger.warn('startCalendarEvent: no calendar #$calId found');
          continue;
        }
        Event event = Event(calendar.id,
            title: title,
            start: start,
            end: end,
            location: location,
            description: description);
        var id = await inserOrUpdate(event);
        newEvents.add(
            CalendarEventId(calendarId: calId.toString(), eventId: id ?? ''));
        logger
            .log('added calendar event ID: $id to calendar ID: ${calendar.id}');
        await Future.delayed(const Duration(milliseconds: 100));
      }

      /// cache event id
      bridge.lastCalendarEventIds = await Cache.setValue<List<CalendarEventId>>(
          CacheKeys.calendarLastEventIds, newEvents);
    }
  }

  Future<void> completeCalendarEvent(TrackPointData tpData) async {
    logger.log('start calender finish process');
    List<CalendarEventId> calIds = await Cache.getValue<List<CalendarEventId>>(
        CacheKeys.calendarLastEventIds, []);

    /// get dates
    final berlin = getLocation(AppSettings.timeZone);
    var start = TZDateTime.from(tpData.timeStart, berlin);
    var end = TZDateTime.from(tpData.timeEnd, berlin);
    var title =
        '${tpData.aliasModels.isNotEmpty ? tpData.aliasModels.first.title : tpData.addressText}; ${tpData.durationText}';
    var location =
        'maps.google.com?q=${tpData.gpslastStatusChange.lat},${tpData.gpslastStatusChange.lon}';
    var description =
        '${tpData.aliasModels.isNotEmpty ? tpData.aliasModels.first.title : tpData.addressText}\n'
        '${start.day}.${start.month}. - ${tpData.durationText}\n'
        '(${start.hour}.${start.minute} - ${end.hour}.${end.minute})\n\n'
        'Arbeiten:\n${tpData.tasksText}\n\n'
        'Mitarbeiter:\n${tpData.usersText}\n\n'
        'Notizen: ${tpData.trackPointNotes.isEmpty ? '-' : tpData.trackPointNotes}';

    logger.log('start iter through calendars');
    for (var calId in calIds) {
      logger.log('try to find calendar ${calId.calendarId}::${calId.eventId}');
      Calendar? calendar = await calendarById(calId.calendarId);
      if (calendar == null) {
        logger.warn('complete/update event: no calendar for found');
        continue;
      }
      logger.log('found calendar  ${calId.calendarId}::${calId.eventId}');
      Event event = Event(calendar.id,
          eventId: calId.eventId.isEmpty ? null : calId.eventId,
          title: title,
          start: start,
          end: end,
          location: location,
          description: description);
      String? id = await inserOrUpdate(event);
      calId.eventId = id ?? '';
      logger
          .log('finished calendar event ${calId.calendarId}::${calId.eventId}');
    }
    // clear calendar cache
    await Cache.setValue<List<CalendarEventId>>(
        CacheKeys.calendarLastEventIds, []);
    tpData.calendarEventIds.clear();
    tpData.calendarEventIds.addAll(calIds);
  }
}
