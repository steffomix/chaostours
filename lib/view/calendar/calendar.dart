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

import 'package:chaostours/conf/app_routes.dart';
import 'package:chaostours/model/model_trackpoint.dart';
import 'package:flutter/material.dart';
import 'package:calendar_view/calendar_view.dart';

import 'package:chaostours/view/system/app_widgets.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/util.dart' as util;
//import 'package:chaostours/util.dart' as util;

enum _View {
  day,
  week,
  month;
}

class WidgetCalendar extends StatefulWidget {
  const WidgetCalendar({super.key});

  @override
  State<WidgetCalendar> createState() => _WidgetCalendar();
}

class _WidgetCalendar extends State<WidgetCalendar> {
  // ignore: unused_field
  static final Logger logger = Logger.logger<WidgetCalendar>();

  _View _currentView = _View.week;
  bool _eventsLoaded = false;

  @override
  void initState() {
    super.initState();
  }

  Future<bool> loadEvents() async {
    if (_eventsLoaded) {
      return true;
    }
    AppWidgets.calendarEventController.removeWhere((element) => true);

    var trackpoints = await ModelTrackPoint.select(limit: 600);
    var currentDate = DateTime.now().subtract(const Duration(days: 5));
    const dur = Duration(hours: 5);
    for (var tp in trackpoints) {
      final event = CalendarEventData<ModelTrackPoint>(
          title:
              '${tp.locationModels.firstOrNull?.title ?? tp.address}\n${util.formatDuration(tp.duration)}',
          date: tp.timeStart,
          endDate: tp.timeEnd,
          startTime: tp.timeStart,
          endTime: tp.timeEnd.add(const Duration(minutes: 10)),
          event: tp);
      currentDate = currentDate.add(dur).add(dur);
      AppWidgets.calendarEventController.add(event);
    }
    _eventsLoaded = true;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return AppWidgets.scaffold(context,
        body: FutureBuilder(
          future: loadEvents(),
          builder: (context, snapshot) {
            return AppWidgets.checkSnapshot(context, snapshot) ??
                renderCalendar();
          },
        ),
        navBar: BottomNavigationBar(
          currentIndex: _currentView.index,
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.calendar_view_day), label: 'Day'),
            BottomNavigationBarItem(
                icon: Icon(Icons.calendar_view_week), label: 'Week'),
            BottomNavigationBarItem(
                icon: Icon(Icons.calendar_view_month), label: 'Month'),
            BottomNavigationBarItem(
                icon: Icon(Icons.update_rounded), label: 'Reload'),
          ],
          onTap: (id) {
            if (id == 3) {
              setState(() {
                _eventsLoaded = false;
              });
              return;
            }
            setState(() {
              _currentView = _View.values[id];
            });
          },
        ));
  }

  Widget renderCalendar() {
    switch (_currentView) {
      case _View.day:
        return DayView(
          heightPerMinute: 5,
          onEventTap: (List<CalendarEventData<ModelTrackPoint>> events, date) {
            Navigator.pushNamed(context, AppRoutes.editTrackPoint.route,
                arguments: events.firstOrNull?.event?.id);
          },
          controller: AppWidgets.calendarEventController,
        );

      case _View.week:
        return WeekView(
          heightPerMinute: 5,
          onEventTap: (List<CalendarEventData<ModelTrackPoint>> events, date) {
            Navigator.pushNamed(context, AppRoutes.editTrackPoint.route,
                arguments: events.firstOrNull?.event?.id);
          },
          controller: AppWidgets.calendarEventController,
        );

      case _View.month: // month
        return MonthView(
          onPageChange: (date, page) {},
          onEventTap: (event, date) {
            Navigator.pushNamed(context, AppRoutes.editTrackPoint.route,
                arguments: event.event?.id);
          },
          controller: AppWidgets.calendarEventController,
          //weekTitleHeight: 70,
        );

      //
    }
  }
}
