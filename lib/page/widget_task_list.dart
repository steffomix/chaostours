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
          title: Text(task.task,
              style: TextStyle(
                  decoration: task.deleted > 0
                      ? TextDecoration.lineThrough
                      : TextDecoration.none)),
          subtitle: Text(task.notes),
          leading: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.editTasks.route,
                    arguments: task.id);
              }));
    }).toList();

    return AppWidgets.scaffold(context,
        body: ListView(children: [
          Center(
            child: IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.editTasks.route,
                    arguments: 0);
              },
            ),
          ),
          ...tasks
        ]));
  }
}
