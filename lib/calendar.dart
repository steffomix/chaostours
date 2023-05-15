import 'package:device_calendar/device_calendar.dart';
import 'package:timezone/timezone.dart';
import 'package:flutter/services.dart';

///
import 'package:chaostours/logger.dart';
import 'package:chaostours/cache.dart';
import 'package:chaostours/data_bridge.dart';

class AppCalendar {
  static final Logger logger = Logger.logger<AppCalendar>();

  late DeviceCalendarPlugin _deviceCalendarPlugin;

  AppCalendar() {
    _deviceCalendarPlugin = DeviceCalendarPlugin();
  }

  final List<Calendar> calendars = [];

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

  String getCacheIdFromCalendar(Calendar c) {
    return <String>[
      c.id?.toString() ?? '0',
      c.name ?? '',
      c.accountName ?? '',
      c.accountType ?? ''
    ].join('\t');
  }

  Future<Calendar?> getCalendarfromCacheId() async {
    try {
      var cache =
          await Cache.getValue<String>(CacheKeys.selectedCalendarId, '');
      List<String> parts = cache.split('\t');
      for (var cal in calendars) {
        if (cal.id == parts[0] &&
            cal.name == parts[1] &&
            cal.accountName == parts[2] &&
            cal.accountType == parts[3]) {
          return cal;
        }
      }
    } catch (e, stk) {
      logger.error('getCalendarFromCacheId: $e', stk);
    }
    return null;
  }
}
