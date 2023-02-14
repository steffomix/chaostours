import 'package:chaostours/widget/widgets.dart';
import 'package:flutter/material.dart';

///
import 'package:chaostours/logger.dart';
import 'package:chaostours/model/model_task.dart';

class WidgetTaskList extends StatefulWidget {
  const WidgetTaskList({super.key});

  @override
  State<WidgetTaskList> createState() => _WidgetTaskList();
}

class _WidgetTaskList extends State<WidgetTaskList> {
  static final Logger logger = Logger.logger<WidgetTaskList>();

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    List<ListTile> tasks = ModelTask.getAll().map((ModelTask task) {
      return ListTile(
          title: Text(task.task),
          subtitle: Text(task.notes),
          leading: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.editTasks.route,
                    arguments: task.id);
              }));
    }).toList();

    return ListView(children: tasks);
  }
}
