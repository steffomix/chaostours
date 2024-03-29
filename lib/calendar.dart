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

import 'package:device_calendar/device_calendar.dart';

///
import 'package:chaostours/database/cache.dart';
import 'package:chaostours/conf/app_user_settings.dart';
import 'package:chaostours/logger.dart';

class CalendarEventId {
  int locationGroupId;
  String calendarId;
  String eventId;
  static const String separator = ',';

  CalendarEventId(
      {required this.locationGroupId, this.calendarId = '', this.eventId = ''});

  @override
  String toString() {
    return '$locationGroupId$separator$calendarId$separator$eventId';
  }

  static CalendarEventId toObject(String s) {
    var parts = s.split(separator);

    if (parts.length == 3) {
      return CalendarEventId(
          locationGroupId: int.parse(parts[0]),
          calendarId: parts[1],
          eventId: parts[2]);
    } else if (parts.length == 2) {
      return CalendarEventId(
          locationGroupId: int.parse(parts[0]), eventId: parts[1]);
    } else {
      return CalendarEventId(locationGroupId: 0, eventId: '');
    }
  }
}

class AppCalendar {
  static final Logger logger = Logger.logger<AppCalendar>();

  final calendarPlugin = DeviceCalendarPlugin();

  Future<String> getTimeZone() async {
    Cache key = Cache.appSettingTimeZone;
    return await key.load<String>(AppUserSetting(key).defaultValue as String);
  }

  Future<String?> inserOrUpdate(Event e) async {
    Result<String>? id = await calendarPlugin.createOrUpdateEvent(e);
    return id?.data;
  }

  Future<List<Event?>> getEventsById(
      {required String calendarId, required String eventId}) async {
    var params = RetrieveEventsParams(eventIds: [eventId]);
    var events = await calendarPlugin.retrieveEvents(calendarId, params);
    return events.data ?? <Event>[];
  }

  Future<List<Calendar>> loadCalendars() async {
    var calendars = <Calendar>[];
    try {
      var permissionsGranted = await calendarPlugin.hasPermissions();
      if (permissionsGranted.isSuccess &&
          (permissionsGranted.data == null ||
              permissionsGranted.data == false)) {
        permissionsGranted = await calendarPlugin.requestPermissions();
        if (!permissionsGranted.isSuccess ||
            permissionsGranted.data == null ||
            permissionsGranted.data == false) {
          var msg = 'No Calendar access permission granted by User';
          logger.fatal(msg, StackTrace.current);
          throw msg;
        }
      }

      final calendarsResult = await calendarPlugin.retrieveCalendars();
      if (calendarsResult.hasErrors) {
        List<String> err = [];
        calendarsResult.errors.map((e) {
          err.add(e.errorMessage);
        });
        var note = await Cache.backgroundTrackPointNotes.load<String>('');
        await Cache.backgroundTrackPointNotes
            .save<String>('$note\n\n${err.join('\n\n')}');
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

  Future<Calendar?> calendarById(String? id) async {
    List<Calendar> calendars = await loadCalendars();
    try {
      for (var c in calendars) {
        if (c.id == id) {
          return c;
        }
      }
    } catch (e) {
      logger.warn('getCalendarFromCacheId: $e');
    }
    return null;
  }
}
