import 'package:device_calendar/device_calendar.dart';
import 'package:timezone/timezone.dart';
import 'package:flutter/services.dart';

///
import 'package:chaostours/logger.dart';
import 'package:chaostours/cache.dart';
import 'package:chaostours/data_bridge.dart';
import 'package:chaostours/trackpoint_data.dart';

class AppCalendar {
  static final Logger logger = Logger.logger<AppCalendar>();

  DeviceCalendarPlugin _deviceCalendarPlugin = DeviceCalendarPlugin();

  final List<Calendar> calendars = [];
  final bridge = DataBridge.instance;

  Future<Result<String>?> inserOrUpdate(Event e) async {
    Result<String>? id = await _deviceCalendarPlugin.createOrUpdateEvent(e);
    return id;
  }

  Future<Event?> getEventById(String id) async {
    Calendar? cal = await getCalendarfromCacheId();
    if (cal != null) {
      var params = RetrieveEventsParams(eventIds: [id]);
      var events = await _deviceCalendarPlugin.retrieveEvents(cal.id, params);
      if (events.isSuccess) {
        List<Event>? data = events.data ?? <Event>[];
        if (data.isNotEmpty) {
          var event = data.first;
          return event;
        }
      }
    }
    return null;
  }

  Future<void> retrieveCalendars() async {
    try {
      var permissionsGranted = await _deviceCalendarPlugin.hasPermissions();
      if (permissionsGranted.isSuccess &&
          (permissionsGranted.data == null ||
              permissionsGranted.data == false)) {
        permissionsGranted = await _deviceCalendarPlugin.requestPermissions();
        if (!permissionsGranted.isSuccess ||
            permissionsGranted.data == null ||
            permissionsGranted.data == false) {
          return;
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
      calendars.clear();
      calendars.addAll(calendarsResult.data as List<Calendar>);
    } catch (e, stk) {
      logger.error('retrieve calendars: $e', stk);
    }
  }

  Future<Calendar?> getCalendarfromCacheId() async {
    try {
      var cache =
          await Cache.getValue<String>(CacheKeys.selectedCalendarId, '');
      for (var c in calendars) {
        if (c.id == cache) {
          return c;
        }
      }
    } catch (e, stk) {
      logger.error('getCalendarFromCacheId: $e', stk);
    }
    return null;
  }

  Future<String?> startCalendarEvent(TrackPointData tpData) async {
    try {
      var appCalendar = AppCalendar();
      await appCalendar.retrieveCalendars();
      if (appCalendar.calendars.isNotEmpty) {
        /// get dates
        final berlin = getLocation('Europe/Berlin');
        var start = TZDateTime.from(tpData.tStart, berlin);
        var end = start.add(const Duration(minutes: 2));

        /// get calendar
        Calendar? calendar; // = await appCalendar.getCalendarfromCacheId();
        for (var c in appCalendar.calendars) {
          if (c.id == tpData.calendarId) {
            calendar = c;
            break;
          }
        }

        /// get lastEvent
        if (calendar != null) {
          var title =
              'Ankunft ${tpData.aliasList.isNotEmpty ? tpData.aliasList.first.alias : tpData.addressText} - ${start.hour}.${start.minute}';
          var location =
              'maps.google.com?q=${tpData.gpslastStatusChange.lat},${tpData.gpslastStatusChange.lon}';
          var description =
              '${tpData.aliasList.isNotEmpty ? tpData.aliasList.first.alias : tpData.addressText}\n'
              'am ${start.day}.${start.month}.${start.year}\n'
              'um ${start.hour}.${start.minute} - unbekannt)\n\n'
              'Arbeiten: ...\n\n'
              'Mitarbeiter:\n${tpData.usersText}\n\n'
              'Notizen: ...';
          Event event = Event(calendar.id,
              title: title,
              start: start,
              end: end,
              location: location,
              description: description);
          var id = await appCalendar.inserOrUpdate(event);
          logger.log('added calendar event');
          return id?.data;
        } else {
          logger.warn('no calendar for adding event found');
        }
      }
    } catch (e, stk) {
      logger.error('create calendar event: $e', stk);
    }
    return null;
  }

  Future<String?> completeCalendarEvent(TrackPointData tpData) async {
    try {
      var appCalendar = AppCalendar();
      await appCalendar.retrieveCalendars();
      if (appCalendar.calendars.isNotEmpty) {
        /// get dates
        final berlin = getLocation('Europe/Berlin');
        var start = TZDateTime.from(tpData.tStart, berlin);
        var end = TZDateTime.from(tpData.tEnd, berlin);

        /// get calendar
        Calendar? calendar; // = await appCalendar.getCalendarfromCacheId();
        for (var c in appCalendar.calendars) {
          if (c.id == tpData.calendarId) {
            calendar = c;
            break;
          }
        }

        /// get lastEvent
        if (calendar != null) {
          Event? lastEvent =
              await appCalendar.getEventById(tpData.calendarEventId);
          String? eventId;
          if (lastEvent != null) {
            eventId = lastEvent.eventId;
          }

          var title =
              '${tpData.aliasList.isNotEmpty ? tpData.aliasList.first.alias : tpData.addressText}; ${tpData.durationText}';
          var location =
              'maps.google.com?q=${tpData.gpslastStatusChange.lat},${tpData.gpslastStatusChange.lon}';
          var description =
              '${tpData.aliasList.isNotEmpty ? tpData.aliasList.first.alias : tpData.addressText}\n'
              '${start.day}.${start.month}. - ${tpData.durationText}\n'
              '(${start.hour}.${start.minute} - ${end.hour}.${end.minute})\n\n'
              'Arbeiten:\n${tpData.tasksText}\n\n'
              'Mitarbeiter:\n${tpData.usersText}\n\n'
              'Notizen: ${tpData.trackPointNotes.isEmpty ? '-' : tpData.trackPointNotes}';
          Event event = Event(calendar.id,
              eventId: eventId,
              title: title,
              start: start,
              end: end,
              location: location,
              description: description);
          var data = await appCalendar.inserOrUpdate(event);
          logger.log('completed calendar event');
          return data?.data;
        } else {
          logger.warn('no calendar for completing event found');
        }
      }
    } catch (e, stk) {
      logger.error(
          'complete or update calendarID:${bridge.selectedCalendarId} eventID:${bridge.lastCalendarEventId}: $e',
          stk);
    }
    return null;
  }
}
