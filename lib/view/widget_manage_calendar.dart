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

import 'package:chaostours/view/app_widgets.dart';
import 'package:flutter/material.dart';
import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';

///
import 'package:chaostours/logger.dart';
import 'package:chaostours/cache.dart';
import 'package:chaostours/calendar.dart';

class WidgetManageCalendar extends StatefulWidget {
  const WidgetManageCalendar({super.key});

  @override
  State<WidgetManageCalendar> createState() => _WidgetManageCalendarState();
}

class _WidgetManageCalendarState extends State<WidgetManageCalendar> {
  static final Logger logger = Logger.logger<WidgetManageCalendar>();
  late AppCalendar appCalendar;

  _WidgetManageCalendarState() {
    appCalendar = AppCalendar();
  }

  Calendar? selectedCalendar;

  @override
  void initState() {
    appCalendar.retrieveCalendars().then((_) async {
      selectedCalendar = await appCalendar.getCalendarfromCacheId();
      if (mounted) {
        setState(() {});
      }
    });
    super.initState();
  }

  Widget calendarList() {
    List<Widget> tiles = [
      const Center(
          child: Text('Selected Calendar',
              style: TextStyle(fontWeight: FontWeight.bold))),
      ListTile(
        title: Text(selectedCalendar?.name ?? ' --- '),
        subtitle: Text(selectedCalendar?.accountName ?? ''),
      ),
      AppWidgets.divider()
    ];
    var i = 1;
    for (var cal in appCalendar.calendars) {
      tiles.add(ListTile(
        title: Text(cal.name ?? 'Calendar $i'),
        subtitle: Text(cal.accountName ?? 'Unknown account'),
        onTap: (() async {
          await Cache.setValue<String>(
              CacheKeys.selectedCalendarId, cal.id ?? '');
          selectedCalendar = cal;
          Fluttertoast.showToast(msg: 'Calendar selected');
          if (mounted) {
            setState(() {});
          }
        }),
      ));
    }

    return ListView(children: tiles);
  }

  @override
  Widget build(BuildContext context) {
    return AppWidgets.scaffold(context,
        body: calendarList(),
        appBar: AppBar(title: const Text('Select Calendar')));
  }
}
