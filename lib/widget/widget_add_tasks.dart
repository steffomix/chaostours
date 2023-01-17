// ignore_for_file: no_logic_in_create_state

import 'package:flutter/material.dart';
//
import 'package:chaostours/model/model_task.dart';
import 'package:chaostours/model/model_trackpoint.dart';
import 'package:chaostours/events.dart';
import 'package:chaostours/event_manager.dart';
import 'package:chaostours/enum.dart';
import 'package:chaostours/events.dart';

///
/// checkbox
///
class WidgedTaskCheckbox extends StatefulWidget {
  final ModelTrackPoint trackPoint;
  final ModelTask task;

  const WidgedTaskCheckbox(
      {super.key, required this.trackPoint, required this.task});

  @override
  State<StatefulWidget> createState() =>
      _WidgedTaskCheckbox(trackPoint: trackPoint, task: task);
}

class _WidgedTaskCheckbox extends State<WidgedTaskCheckbox> {
  final ModelTrackPoint trackPoint;
  final ModelTask task;
  bool? checked;
  _WidgedTaskCheckbox({required this.trackPoint, required this.task});
  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
        value: trackPoint.idTask.contains(task.id),
        onChanged: (bool? val) {
          val ??= false;

          val == true ? trackPoint.addTask(task) : trackPoint.removeTask(task);
          ModelTrackPoint.update(trackPoint);
          setState(() {
            checked = val;
          });
        },
        title: Text(task.task),
        subtitle: Text(task.notes));
  }
}

///
/// CheckBox list
///
class WidgetAddTasks extends StatefulWidget {
  final ModelTrackPoint trackPoint;

  const WidgetAddTasks({super.key, required this.trackPoint});

  @override
  State<StatefulWidget> createState() =>
      _WidgetAddTasksState(trackPoint: trackPoint);
}

void onBackToMainPane() {
  EventManager.fire<EventOnMainPaneChanged>(
      EventOnMainPaneChanged(Panes.instance(Panes.trackPointList)));
}

Widget backToMainPane() {
  return const Center(
      child:
          IconButton(icon: Icon(Icons.done_all), onPressed: onBackToMainPane));
}

class _WidgetAddTasksState extends State<WidgetAddTasks> {
  final ModelTrackPoint trackPoint;

  _WidgetAddTasksState({required this.trackPoint});

  @override
  Widget build(BuildContext context) {
    List<ModelTask> tasks = ModelTask.getAll();
    List<Widget> widgets = [backToMainPane()];
    for (var task in tasks) {
      widgets.add(WidgedTaskCheckbox(trackPoint: trackPoint, task: task));
    }
    return ListView(children: widgets);
  }
}
