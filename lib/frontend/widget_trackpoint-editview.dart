import 'package:chaostours/events.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:chaostours/enum.dart';
import 'package:chaostours/model.dart';

class TrackPointEditView extends StatefulWidget {
  const TrackPointEditView({super.key});

  @override
  State<StatefulWidget> createState() => _TrackPointEditViewState();
}

class Task implements Comparable<Task> {
  final int id;
  final String text;
  final String description;
  bool checked = false;
  Task(this.id, this.text, [this.description = '']);

  @override
  int compareTo(Task other) => id - other.id;
}

class _TrackPointEditViewState extends State<TrackPointEditView> {
  _TrackPointEditViewState();
  static List<Task> tasks = [
    Task(1, 'schindern'),
    Task(2, 'malochen'),
    Task(3, 'rumstehen', 'und quasseln'),
    Task(1, 'schindern'),
    Task(2, 'malochen'),
    Task(3, 'rumstehen', 'und quasseln'),
    Task(1, 'schindern'),
    Task(2, 'malochen'),
    Task(3, 'rumstehen', 'und quasseln'),
    Task(1, 'schindern'),
    Task(2, 'malochen'),
    Task(3, 'rumstehen', 'und quasseln'),
    Task(1, 'schindern'),
    Task(2, 'malochen'),
    Task(3, 'rumstehen', 'und quasseln'),
  ];

  Widget _checkBox(Task task, [bool checked = false]) {
    return CheckboxListTile(
        value: task.checked,
        onChanged: (bool? checked) {
          task.checked = !task.checked;
          setState(() {});
        },
        title: Text(task.text),
        subtitle: Text(task.description));
  }

  List<Widget> _taskList() {
    List<Widget> items = [];
    for (var t in tasks) {
      items.add(_checkBox(t));
    }
    return items;
  }

  @override
  void dispose() {
    // cancel listeners!
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget back = Center(
        child: IconButton(
      icon: const Icon(Icons.done_all),
      onPressed: () {
        eventBusAppBodyScreenChanged.fire(AppBodyScreens.trackPointListView);
      },
    ));
    return ListView(
      children: [back, ..._taskList()],
    );
  }
}
