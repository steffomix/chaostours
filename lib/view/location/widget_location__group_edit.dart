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

import 'package:chaostours/database/database.dart';
import 'package:chaostours/statistics/location_statistics.dart';
import 'package:chaostours/view/trackpoint/widget_trackpoint_list.dart';
import 'package:flutter/material.dart';
import 'package:device_calendar/device_calendar.dart';

///
import 'package:chaostours/view/system/app_widgets.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/model/model_location_group.dart';
import 'package:chaostours/conf/app_routes.dart';
import 'package:chaostours/calendar.dart';
import 'package:permission_handler/permission_handler.dart';

enum _DisplayMode {
  selectCalendar,
  editGroup;
}

class WidgetLocationGroupEdit extends StatefulWidget {
  const WidgetLocationGroupEdit({super.key});

  @override
  State<WidgetLocationGroupEdit> createState() => _WidgetLocationGroupEdit();
}

class _WidgetLocationGroupEdit extends State<WidgetLocationGroupEdit> {
  // ignore: unused_field
  static final Logger logger = Logger.logger<WidgetLocationGroupEdit>();
  _DisplayMode _displayMode = _DisplayMode.editGroup;
  ModelLocationGroup? _model;
  int _countLocation = 0;
  Calendar? _calendar;
  final _titleUndoController = UndoHistoryController();

  final _descriptionUndoController = UndoHistoryController();

  Map<TableLocationGroup, bool Function()> fieldsMap = {};

  void generateMap(ModelLocationGroup model) {
    fieldsMap.clear();
    fieldsMap.addAll({
      TableLocationGroup.withCalendarHtml: () => model.calendarHtml,
      TableLocationGroup.withCalendarGps: () => model.calendarGps,
      TableLocationGroup.withCalendarTimeStart: () => model.calendarTimeStart,
      TableLocationGroup.withCalendarTimeEnd: () => model.calendarTimeEnd,
      TableLocationGroup.withCalendarDuration: () => model.calendarDuration,
      TableLocationGroup.withCalendarAddress: () => model.calendarAddress,
      TableLocationGroup.withCalendarFullAddress: () =>
          model.calendarFullAddress,
      TableLocationGroup.withCalendarTrackpointNotes: () =>
          model.calendarTrackpointNotes,
      TableLocationGroup.withCalendarLocation: () => model.calendarLocation,
      TableLocationGroup.withCalendarLocationNearby: () =>
          model.calendarLocationNearby,
      TableLocationGroup.withCalendarNearbyLocationDescription: () =>
          model.calendarNearbyLocationDescription,
      TableLocationGroup.withCalendarLocationDescription: () =>
          model.calendarLocationDescription,
      TableLocationGroup.withCalendarUsers: () => model.calendarUsers,
      TableLocationGroup.withCalendarUserNotes: () => model.calendarUserNotes,
      TableLocationGroup.withCalendarUserDescription: () =>
          model.calendarUserDescription,
      TableLocationGroup.withCalendarTasks: () => model.calendarTasks,
      TableLocationGroup.withCalendarTaskNotes: () => model.calendarTaskNotes,
      TableLocationGroup.withCalendarTaskDescription: () =>
          model.calendarTaskDescription,
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  void render() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<ModelLocationGroup> createLocationGroup() async {
    var count = await ModelLocationGroup.count();
    var model = await ModelLocationGroup(title: '#${count + 1}').insert();
    return model;
  }

  Future<ModelLocationGroup?> loadLocationGroup(int? id) async {
    if (id == null) {
      _model = await createLocationGroup();
    } else {
      _model = await ModelLocationGroup.byId(id);
    }
    if (_model == null && mounted) {
      if (mounted) {
        Future.microtask(() => Navigator.pop(context));
      }
      throw 'Group #$id not found';
    } else {
      _countLocation = await _model!.locationCount();
      if (await Permission.calendarFullAccess.isGranted) {
        _calendar = await AppCalendar().calendarById(_model!.idCalendar);
      }
      generateMap(_model!);
      return _model;
    }
  }

  @override
  Widget build(BuildContext context) {
    int? id = ModalRoute.of(context)?.settings.arguments as int?;

    return FutureBuilder<ModelLocationGroup?>(
      future: loadLocationGroup(id),
      builder: (context, snapshot) {
        return AppWidgets.checkSnapshot(context, snapshot) ?? body();
      },
    );
  }

  Widget body() {
    return scaffold(_displayMode == _DisplayMode.editGroup
        ? editGroup()
        : AppWidgets.calendarSelector(
            context: context,
            selectedCalendar: _calendar,
            onSelect: (cal) {
              _model!.idCalendar = cal.id ?? '';
              _model!.update().then(
                (value) {
                  _displayMode = _DisplayMode.editGroup;
                  render();
                },
              );
            },
          ));
  }

  Widget scaffold(Widget body) {
    return AppWidgets.scaffold(context,
        title: 'Edit Location Group',
        body: body,
        navBar: AppWidgets.navBarCreateItem(context, name: 'Location group',
            onCreate: () async {
          final model = await AppWidgets.createLocationGroup(context);
          if (model != null && mounted) {
            await Navigator.pushNamed(
                context, AppRoutes.editLocationGroup.route,
                arguments: model.id);
            render();
          }
        }));
  }

  Widget editGroup() {
    return ListView(padding: const EdgeInsets.all(5), children: [
      /// Trackpoints button
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: FilledButton(
                  onPressed: () => Navigator.pushNamed(
                      context, AppRoutes.listTrackpoints.route,
                      arguments: TrackpointListArguments.locationGroup
                          .arguments(_model!.id)),
                  child: const Text('Trackpoints'))),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: FilledButton(
                  onPressed: () async {
                    var stats =
                        await LocationStatistics.groupStatistics(_model!);

                    if (mounted) {
                      AppWidgets.statistics(context, stats: stats,
                          reload: (DateTime start, DateTime end) async {
                        return await LocationStatistics.groupStatistics(
                            stats.model,
                            start: start,
                            end: end);
                      });
                    }
                  },
                  child: const Text('Statistics')))
        ],
      ),

      /// groupname
      ListTile(
          dense: true,
          trailing: ValueListenableBuilder<UndoHistoryValue>(
            valueListenable: _titleUndoController,
            builder: (context, value, child) {
              return IconButton(
                icon: const Icon(Icons.undo),
                onPressed: value.canUndo
                    ? () {
                        _titleUndoController.undo();
                      }
                    : null,
              );
            },
          ),
          title: Container(
              padding: const EdgeInsets.all(10),
              child: TextField(
                decoration:
                    const InputDecoration(label: Text('Location Group Name')),
                onChanged: ((value) {
                  _model!.title = value;
                  _model!.update();
                }),
                maxLines: 3,
                minLines: 3,
                controller: TextEditingController(text: _model?.title),
              ))),
      AppWidgets.divider(),

      /// notes
      ListTile(
          dense: true,
          trailing: ValueListenableBuilder<UndoHistoryValue>(
            valueListenable: _descriptionUndoController,
            builder: (context, value, child) {
              return IconButton(
                icon: const Icon(Icons.undo),
                onPressed: value.canUndo
                    ? () {
                        _descriptionUndoController.undo();
                      }
                    : null,
              );
            },
          ),
          title: Container(
              padding: const EdgeInsets.all(10),
              child: TextField(
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(label: Text('Notizen')),
                maxLines: null,
                minLines: 3,
                controller: TextEditingController(text: _model?.description),
                onChanged: (value) {
                  _model!.description = value.trim();
                  _model!.update();
                },
              ))),
      AppWidgets.divider(),

      /// deleted
      ListTile(
          title: const Text('Active'),
          subtitle: const Text('This Group is active and visible'),
          leading: AppWidgets.checkbox(
            value: _model!.isActive,
            onChanged: (val) {
              _model!.isActive = val ?? false;
              _model!.update();
            },
          )),

      AppWidgets.divider(),

      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: FilledButton(
          child: Text('Show $_countLocation locations from this group'),
          onPressed: () => Navigator.pushNamed(
                  context, AppRoutes.listLocationsFromLocationGroup.route,
                  arguments: _model!.id)
              .then((value) {
            render();
          }),
        ),
      ),

      AppWidgets.divider(),

      /// calendar
      Column(children: [
        Text('Calendar', style: Theme.of(context).textTheme.bodyLarge),
        Column(mainAxisSize: MainAxisSize.min, children: [
          _calendar == null
              ? FilledButton(
                  onPressed: () {
                    _displayMode = _DisplayMode.selectCalendar;
                    render();
                  },
                  child: const Text('add Calendar'),
                )
              : ListTile(
                  leading: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () async {
                        _model!.idCalendar = '';
                        await _model!.update();
                        render();
                      }),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () {
                      _displayMode = _DisplayMode.selectCalendar;
                      render();
                    },
                  ),
                  title: Text(
                      '${_calendar?.name ?? '-'}\n${_calendar?.accountName ?? ''}'),
                  subtitle: Text('Default Calendar',
                      style: _calendar?.isDefault ?? false
                          ? null
                          : const TextStyle(
                              decoration: TextDecoration.lineThrough)),
                )
        ])
      ]),
      ...calendarOptions(),
    ]);
  }

  Widget renderCalendarOption({
    required TableLocationGroup field,
    required String title,
    required String description,
  }) {
    return ListTile(
      trailing: AppWidgets.checkbox(
          value: fieldsMap[field]?.call() ?? false,
          onChanged: (bool? state) {
            state = (state ?? false);
            updateField(field, state);
          }),
      title: Text(title),
      subtitle: Text(description),
    );
  }

  List<Widget> calendarOptions() {
    return _calendar == null
        ? []
        : [
            AppWidgets.divider(),
            Center(
                child: Text('Calendar Options',
                    style: Theme.of(context).textTheme.bodyLarge)),
            const Text(
                'All values are displayed in the calendar event body in same order as listed below.'),
            const Text(
                'The location title will be set to the event title - if activated. Otherwise only the location #id will be used.'),

            ///
            /// withCalendarTimeStart
            renderCalendarOption(
                field: TableLocationGroup.withCalendarTimeStart,
                title: 'Start Date and Time',
                description: ''),

            /// withCalendarTimeEnd
            renderCalendarOption(
                field: TableLocationGroup.withCalendarTimeEnd,
                title: 'End Date and Time',
                description: ''),

            /// withCalendarTimeEnd
            renderCalendarOption(
                field: TableLocationGroup.withCalendarAllDay,
                title:
                    'Write as All Day Event. End date and time will be the same as start date and time.',
                description: ''),

            /// withCalendarDuration
            renderCalendarOption(
                field: TableLocationGroup.withCalendarDuration,
                title: 'Duration',
                description:
                    'The duration of the event. If you have set teh Event as an all day event, the duration will not be displayed.'),

            ///
            /// withCalendarGps
            renderCalendarOption(
                field: TableLocationGroup.withCalendarGps,
                title: 'GPS data',
                description: 'Latitude and longitude of the location.'),

            /// withCalendarHtml
            renderCalendarOption(
                field: TableLocationGroup.withCalendarHtml,
                title: 'Use Html',
                description:
                    'Wraps gps data into a clickable link to maps.google.com.'),

            ///
            /// withCalendarTrackpointNotes
            renderCalendarOption(
                field: TableLocationGroup.withCalendarTrackpointNotes,
                title: 'Trackpoint notes',
                description: 'General trackpoint notes.'),

            ///
            /// withCalendarLocation
            renderCalendarOption(
                field: TableLocationGroup.withCalendarLocation,
                title: 'Main location name or title',
                description: 'This is also displayed in the event title.\n'
                    'If disabled, only the #id is displayed.'),

            /// withCalendarLocationDescription
            renderCalendarOption(
                field: TableLocationGroup.withCalendarLocationDescription,
                title: 'Location description',
                description: 'Description of the main location.'),

            /// withCalendarLocationNearby
            renderCalendarOption(
                field: TableLocationGroup.withCalendarLocationNearby,
                title: 'Nearby locations',
                description: 'All overlapping location names.'),

            /// withCalendarLocationNotes
            renderCalendarOption(
                field: TableLocationGroup.withCalendarNearbyLocationDescription,
                title: 'Nearby location description',
                description: 'The description of every overlapping location.'),

            /// withCalendarAddress
            renderCalendarOption(
                field: TableLocationGroup.withCalendarAddress,
                title: 'Address',
                description: 'A Comma separated address.'),

            /// withCalendarFullAddress
            renderCalendarOption(
                field: TableLocationGroup.withCalendarFullAddress,
                title: 'Address details',
                description:
                    'Line separated address details with copyright informations from openstreetmap.org at the end.'),

            ///
            /// withCalendarTasks
            renderCalendarOption(
                field: TableLocationGroup.withCalendarTasks,
                title: 'Task',
                description: 'The task name or title'),

            /// withCalendarTaskDescription
            renderCalendarOption(
                field: TableLocationGroup.withCalendarTaskDescription,
                title: 'Task description',
                description: 'The description of the task'),

            /// withCalendarTaskNotes
            renderCalendarOption(
                field: TableLocationGroup.withCalendarTaskNotes,
                title: 'Task trackpoint notes',
                description: 'Trackpoint notes for this task.'),

            ///
            /// withCalendarUsers
            renderCalendarOption(
                field: TableLocationGroup.withCalendarUsers,
                title: 'User',
                description: 'The user name or title.'),

            /// withCalendarUserDescription
            renderCalendarOption(
                field: TableLocationGroup.withCalendarUserDescription,
                title: 'User description.',
                description: 'The description of the user.'),

            /// withCalendarUserNotes
            renderCalendarOption(
                field: TableLocationGroup.withCalendarUserNotes,
                title: 'User trackpoint notes',
                description: 'Trackpoint notes for this user.'),
          ];
  }

  Future<void> updateField(TableLocationGroup field, bool value) async {
    switch (field) {
      case TableLocationGroup.withCalendarHtml:
        _model?.calendarHtml = value;
        break;
      case TableLocationGroup.withCalendarGps:
        _model?.calendarGps = value;
        break;
      case TableLocationGroup.withCalendarTimeStart:
        _model?.calendarTimeStart = value;
        break;
      case TableLocationGroup.withCalendarTimeEnd:
        _model?.calendarTimeEnd = value;
        break;
      case TableLocationGroup.withCalendarDuration:
        _model?.calendarDuration = value;
        break;
      case TableLocationGroup.withCalendarAddress:
        _model?.calendarAddress = value;
        break;
      case TableLocationGroup.withCalendarFullAddress:
        _model?.calendarFullAddress = value;
        break;
      case TableLocationGroup.withCalendarTrackpointNotes:
        _model?.calendarTrackpointNotes = value;
        break;
      case TableLocationGroup.withCalendarLocation:
        _model?.calendarLocation = value;
        break;
      case TableLocationGroup.withCalendarLocationNearby:
        _model?.calendarLocationNearby = value;
        break;
      case TableLocationGroup.withCalendarNearbyLocationDescription:
        _model?.calendarNearbyLocationDescription = value;
        break;
      case TableLocationGroup.withCalendarLocationDescription:
        _model?.calendarLocationDescription = value;
        break;
      case TableLocationGroup.withCalendarUsers:
        _model?.calendarUsers = value;
        break;
      case TableLocationGroup.withCalendarUserNotes:
        _model?.calendarUserNotes = value;
        break;
      case TableLocationGroup.withCalendarUserDescription:
        _model?.calendarUserDescription = value;
        break;
      case TableLocationGroup.withCalendarTasks:
        _model?.calendarTasks = value;
        break;
      case TableLocationGroup.withCalendarTaskNotes:
        _model?.calendarTaskNotes = value;
        break;
      case TableLocationGroup.withCalendarTaskDescription:
        _model?.calendarTaskDescription = value;
        break;

      default:
        logger.error('field $field not implemented', StackTrace.current);
    }
    await _model?.update();
  }
}
