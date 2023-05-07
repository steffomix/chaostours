import 'package:chaostours/view/app_widgets.dart';
import 'package:flutter/material.dart';
import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/services.dart';

///
import 'package:chaostours/logger.dart';

class WidgetManageCalendar extends StatefulWidget {
  const WidgetManageCalendar({super.key});

  @override
  State<WidgetManageCalendar> createState() => _WidgetManageCalendarState();
}

class _WidgetManageCalendarState extends State<WidgetManageCalendar> {
  static final Logger logger = Logger.logger<WidgetManageCalendar>();
  late DeviceCalendarPlugin _deviceCalendarPlugin;

  _WidgetManageCalendarState() {
    _deviceCalendarPlugin = DeviceCalendarPlugin();
  }

  List<Calendar> _calendars = [];

  @override
  void initState() {
    _retrieveCalendars().then((_) {
      if (mounted) {
        setState(() {});
      }
    });
    super.initState();
  }

  Widget calendarList() {
    List<Widget> tiles = [
      const ListTile(
        title: Text('Selected Calendar:'),
        subtitle: Text('none'),
      ),
      AppWidgets.divider()
    ];
    var i = 1;
    for (var cal in _calendars) {
      tiles.add(ListTile(
        title: Text(cal.name ?? 'Calendar $i'),
        subtitle: Text(cal.accountName ?? 'Unknown account'),
      ));
    }

    return ListView(children: tiles);
  }

  @override
  Widget build(BuildContext context) {
    return AppWidgets.scaffold(context, body: calendarList());
  }

  Future<void> _retrieveCalendars() async {
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
      setState(() {
        _calendars = calendarsResult.data as List<Calendar>;
      });
    } on PlatformException catch (e, stk) {
      logger.error('retrieve calendars: $e', stk);
    }
  }
}
