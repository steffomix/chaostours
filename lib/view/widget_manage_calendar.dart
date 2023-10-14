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
import 'package:fluttertoast/fluttertoast.dart';

import 'package:chaostours/app_logger.dart';
import 'package:chaostours/cache.dart';
import 'package:chaostours/calendar.dart';

class WidgetManageCalendar extends StatefulWidget {
  const WidgetManageCalendar({super.key});

  @override
  State<WidgetManageCalendar> createState() => _WidgetManageCalendarState();
}

class _WidgetManageCalendarState extends State<WidgetManageCalendar> {
  static final AppLogger logger = AppLogger.logger<WidgetManageCalendar>();

  AppCalendar appCalendar = AppCalendar();
  Calendar? selectedCalendar;

  @override
  void initState() {
    super.initState();
  }

  Future<void> loadCalendar() async {
    var id = await Cache.getValue(CacheKeys.calendarSelectedId, '');
    selectedCalendar = await appCalendar.calendarById(id);
    if (mounted) {
      setState(() {});
    }
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
              CacheKeys.calendarSelectedId, cal.id ?? '');
          selectedCalendar = cal;
          Fluttertoast.showToast(msg: 'Calendar selected');
          if (mounted) {
            setState(() {});
            Navigator.pop(context);
          }
        }),
      ));
    }
    return ListView(children: tiles);
  }

  @override
  Widget build(BuildContext context) {
    return AppWidgets.scaffold(context,
        body: FutureBuilder(
          future: loadCalendar(),
          builder: (context, snapshot) {
            return AppWidgets.checkSnapshot(snapshot) ??
                ListView.separated(
                  separatorBuilder: (context, index) => AppWidgets.divider(),
                  itemCount: appCalendar.calendars.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return ListTile(
                        title: const Text('Selected Calendar:'),
                        subtitle: Text(
                            '${selectedCalendar?.name ?? ' --- '}\n${selectedCalendar?.accountName ?? ''}'),
                      );
                    } else {
                      var cal = appCalendar.calendars[index - 1];
                      return ListTile(
                        title: Text(cal.name ?? 'Calendar $index'),
                        subtitle: Text(cal.accountName ?? 'Unknown account'),
                        onTap: (() async {
                          await Cache.setValue<String>(
                              CacheKeys.calendarSelectedId, cal.id ?? '');
                          selectedCalendar = cal;
                          Fluttertoast.showToast(msg: 'Calendar selected');
                          if (mounted) {
                            setState(() {});
                            Navigator.pop(context);
                          }
                        }),
                      );
                    }
                  },
                );
          },
        ),
        appBar: AppBar(title: const Text('Select Calendar')));
  }
}
