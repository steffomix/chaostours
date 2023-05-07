import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/services.dart';

///
import 'package:chaostours/logger.dart';

class AppCalendar {
  static final Logger logger = Logger.logger<AppCalendar>();

  late DeviceCalendarPlugin _deviceCalendarPlugin;

  AppCalendar() {
    _deviceCalendarPlugin = DeviceCalendarPlugin();
  }

  final List<Calendar> calendars = [];

  Future<void> inserOrUpdate(Event e) async {
    _deviceCalendarPlugin.createOrUpdateEvent(e);
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

  Calendar? getCalendarfromCacheId(String cache) {
    try {
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
