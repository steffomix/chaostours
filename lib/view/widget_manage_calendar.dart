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

import 'package:flutter/material.dart';
import 'package:device_calendar/device_calendar.dart';
import 'package:fluttertoast/fluttertoast.dart';

///
import 'package:chaostours/view/app_widgets.dart';
import 'package:chaostours/calendar.dart';

class WidgetManageCalendar extends StatefulWidget {
  const WidgetManageCalendar({super.key});

  @override
  State<WidgetManageCalendar> createState() => _WidgetManageCalendarState();
}

class _WidgetManageCalendarState extends State<WidgetManageCalendar> {
  //static final Logger logger = Logger.logger<WidgetManageCalendar>();

  Calendar? selectedCalendar;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return AppWidgets.scaffold(context,
        body: FutureBuilder<List<Calendar>>(
          future: AppCalendar().loadCalendars(),
          builder: (context, snapshot) {
            return AppWidgets.checkSnapshot(snapshot) ??
                AppWidgets.calendarSelector(
                    calendars: snapshot.data,
                    context: context,
                    onSelect: (Calendar cal) async {
                      Fluttertoast.showToast(msg: 'Calendar selected');
                      if (mounted) {
                        setState(() {});
                        Navigator.pop(context);
                      }
                    });
          },
        ),
        appBar: AppBar(title: const Text('Select Calendar')));
  }

  Widget calendarSelector(
      {required BuildContext context,
      required void Function(Calendar cal) onSelect,
      Calendar? selectedCalendar}) {
    return FutureBuilder<List<Calendar>>(
      future: AppCalendar().loadCalendars(),
      builder: (context, snapshot) {
        return AppWidgets.checkSnapshot(snapshot) ??
            ListView.separated(
              separatorBuilder: (context, index) => AppWidgets.divider(),
              itemCount: snapshot.data!.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return ListTile(
                    title: const Text('Selected Calendar:'),
                    subtitle: Text(
                        '${selectedCalendar?.name ?? ' --- '}\n${selectedCalendar?.accountName ?? ''}'),
                  );
                } else {
                  var cal = snapshot.data![index - 1];
                  return ListTile(
                    title: Text(cal.name ?? 'Calendar $index'),
                    subtitle: Text(cal.accountName ?? 'Unknown account'),
                    onTap: (() async {
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
    );
  }
}
