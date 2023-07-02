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
import 'package:fluttertoast/fluttertoast.dart';
//
import 'package:chaostours/conf/app_routes.dart';
import 'package:chaostours/conf/app_colors.dart';
import 'package:chaostours/model/model_user.dart';
import 'package:chaostours/model/model_task.dart';
import 'package:chaostours/model/model_alias.dart';
import 'package:chaostours/model/model_trackpoint.dart';
import 'package:chaostours/trackpoint_data.dart';
import 'package:chaostours/calendar.dart';
import 'package:chaostours/view/app_widgets.dart';
import 'package:chaostours/util.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/screen.dart';
import 'package:chaostours/gps.dart';

///
/// CheckBox list
///
class WidgetEditTrackPoint extends StatefulWidget {
  const WidgetEditTrackPoint({super.key});

  @override
  State<StatefulWidget> createState() => _WidgetAddTasksState();
}

class _WidgetAddTasksState extends State<WidgetEditTrackPoint> {
  Logger logger = Logger.logger<WidgetEditTrackPoint>();

  /// editable fields
  List<int> tpTasks = [];
  List<int> tpUsers = [];
  TextEditingController tpNotes = TextEditingController();

  late ModelTrackPoint trackPoint;

  bool initialized = false;

  /// modify
  ValueNotifier<bool> modified = ValueNotifier<bool>(false);
  void modify() {
    modified.value = true;
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// current trackpoint
  Widget trackPointInfo(BuildContext context) {
    var aliasList = trackPoint.aliasIds.map((id) => ModelAlias.getModel(id));

    return Container(
        padding: const EdgeInsets.all(10),
        child: ListBody(children: [
          Center(
              heightFactor: 2,
              child: aliasList.isEmpty
                  ? TextButton(
                      child: Text('OSM: ${trackPoint.address}'),
                      onPressed: () async {
                        GPS gps = await GPS.gps();
                        await GPS.launchGoogleMaps(gps.lat, gps.lon,
                            trackPoint.gps.lat, trackPoint.gps.lon);
                      },
                    )
                  : TextButton(
                      child: Text(
                          'Alias: ${aliasList.map((e) => e.title).join('\n- ')}'),
                      onPressed: () async {
                        int id = aliasList.first.id;
                        await Navigator.pushNamed(
                            context, AppRoutes.editAlias.route,
                            arguments: id);
                      },
                    )),
          Text(AppWidgets.timeInfo(trackPoint.timeStart, trackPoint.timeEnd)),
        ]));
  }

  List<Widget> taskCheckboxes(context) {
    var referenceList = tpTasks;
    var checkBoxes = <Widget>[];
    for (var tp in ModelTask.getAll()) {
      if (!tp.deleted) {
        checkBoxes.add(createCheckbox(
            this,
            CheckboxController(
                idReference: tp.id,
                referenceList: referenceList,
                deleted: tp.deleted,
                title: tp.title,
                subtitle: tp.notes,
                onToggle: () {
                  modify();
                })));
      }
    }
    return checkBoxes;
  }

  List<Widget> userCheckboxes(context) {
    var referenceList = tpUsers;
    var checkBoxes = <Widget>[];
    for (var tp in ModelUser.getAll()) {
      if (!tp.deleted) {
        checkBoxes.add(createCheckbox(
            this,
            CheckboxController(
                idReference: tp.id,
                referenceList: referenceList,
                deleted: tp.deleted,
                title: tp.title,
                subtitle: tp.notes,
                onToggle: () {
                  modify();
                })));
      }
    }
    return checkBoxes;
  }

  bool dropdownUserIsOpen = false;
  Widget dropdownUser(context) {
    /// render selected users
    List<String> userList = [];
    for (var item in ModelUser.getAll()) {
      if (tpUsers.contains(item.id)) {
        userList.add(item.title);
      }
    }
    String users = userList.isNotEmpty ? '\n- ${userList.join('\n- ')}' : ' - ';

    /// dropdown menu botten with selected users
    List<Widget> items = [
      ElevatedButton(
        child: ListTile(
            trailing: const Icon(Icons.menu), title: Text('Personal:$users')),
        onPressed: () {
          dropdownUserIsOpen = !dropdownUserIsOpen;
          setState(() {});
        },
      ),
      !dropdownUserIsOpen
          ? const SizedBox.shrink()
          : Column(children: userCheckboxes(context))
    ];
    return ListBody(children: items);
  }

  bool dropdownTasksIsOpen = false;
  Widget dropdownTasks(context) {
    /// render selected tasks
    List<String> taskList = [];
    for (var item in ModelTask.getAll()) {
      if (tpTasks.contains(item.id)) {
        taskList.add(item.title);
      }
    }
    String tasks = taskList.isNotEmpty ? '\n- ${taskList.join('\n- ')}' : ' - ';

    /// dropdown menu botten with selected tasks
    List<Widget> items = [
      ElevatedButton(
        child: ListTile(
            trailing: const Icon(Icons.menu), title: Text('Arbeiten:$tasks')),
        onPressed: () {
          dropdownTasksIsOpen = !dropdownTasksIsOpen;
          setState(() {});
        },
      ),
      !dropdownTasksIsOpen
          ? const SizedBox.shrink()
          : Column(children: taskCheckboxes(context))
    ];
    return ListBody(children: items);
  }

  Widget notes(BuildContext context) {
    return Container(
        padding: const EdgeInsets.all(10),
        child: TextField(
            decoration: const InputDecoration(
                label: Text('Notizen'),
                contentPadding: EdgeInsets.all(2),
                border: InputBorder.none),
            //expands: true,
            maxLines: null,
            minLines: 2,
            controller: tpNotes,
            onChanged: (String? s) {
              modify();
            }));
  }

  Widget map(context) {
    Screen screen = Screen(context);
    return SizedBox(
        width: screen.width,
        height: 25,
        child: IconButton(
            icon: const Icon(Icons.map),
            onPressed: () async {
              var gps = await GPS.gps();
              var lat = gps.lat;
              var lon = gps.lon;
              var lat1 = trackPoint.gps.lat;
              var lon1 = trackPoint.gps.lon;
              GPS.launchGoogleMaps(lat, lon, lat1, lon1);
            }));
  }

  ///
  @override
  Widget build(BuildContext context) {
    Widget body;
    try {
      if (!initialized) {
        final id = (ModalRoute.of(context)?.settings.arguments ?? 0) as int;
        trackPoint = ModelTrackPoint.byId(id);
        tpTasks = trackPoint.taskIds;
        tpUsers = trackPoint.userIds;
        tpNotes.text = trackPoint.notes;
        initialized = true;
      }
      Widget divider = AppWidgets.divider();
      body = ListView(children: [
        /// current Trackpoint time info
        map(context),
        trackPointInfo(context),
        divider,
        dropdownTasks(context),
        divider,
        dropdownUser(context),
        divider,
        notes(context),
      ]);
    } catch (e, stk) {
      body = AppWidgets.loading('No valid ID found');
      Future.delayed(const Duration(milliseconds: 500), () {
        Navigator.pop(context);
      });
    }

    return AppWidgets.scaffold(
      context,
      body: body,
      appBar: AppBar(title: const Text('Haltepunkt bearbeiten')),
      navBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          items: [
            // 0 alphabethic
            BottomNavigationBarItem(
                icon: ValueListenableBuilder(
                    valueListenable: modified,
                    builder: ((context, value, child) {
                      return Icon(Icons.done,
                          size: 30,
                          color: modified.value == true
                              ? AppColors.green.color
                              : AppColors.white54.color);
                    })),
                label: 'Speichern'),
            // 1 nearest
            const BottomNavigationBarItem(
                icon: Icon(Icons.cancel), label: 'Abbrechen'),
          ],
          onTap: (int id) async {
            if (id == 0 && modified.value) {
              trackPoint.notes = tpNotes.text;
              await ModelTrackPoint.update(trackPoint);
              await AppCalendar()
                  .completeCalendarEvent(TrackPointData(tp: trackPoint));
              if (mounted) {
                Navigator.pop(context);
              }
              Fluttertoast.showToast(msg: 'Trackpoint updated');
            } else {
              Navigator.pop(context);
            }
          }),
    );
  }
}
