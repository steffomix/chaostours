import 'package:chaostours/view/app_widgets.dart';
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

  bool showDeleted = false;
  String search = '';
  TextEditingController controller = TextEditingController();

  @override
  void dispose() {
    super.dispose();
  }

  Widget taskWidget(BuildContext context, ModelTask task) {
    return ListBody(children: [
      ListTile(
          title: Text(task.task,
              style: TextStyle(
                  decoration: task.deleted
                      ? TextDecoration.lineThrough
                      : TextDecoration.none)),
          subtitle: TextField(
              controller: TextEditingController(text: task.notes),
              style: const TextStyle(fontSize: 12),
              enabled: false,
              readOnly: true,
              minLines: 1,
              maxLines: 5,
              decoration: const InputDecoration(border: InputBorder.none)),
          trailing: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.editTasks.route,
                    arguments: task.id);
              })),
      AppWidgets.divider()
    ]);
  }

  Widget searchWidget(BuildContext context) {
    return TextField(
      controller: controller,
      minLines: 1,
      maxLines: 1,
      decoration: const InputDecoration(
          icon: Icon(Icons.search, size: 30), border: InputBorder.none),
      onChanged: (value) {
        search = value;
        setState(() {});
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> tasks = [];
    for (var item in ModelTask.getAll()) {
      if (!showDeleted && item.deleted) {
        continue;
      }
      if (search.trim().isNotEmpty &&
          (item.task.contains(search) || item.notes.contains(search))) {
        tasks.add(taskWidget(context, item));
      } else {
        tasks.add(taskWidget(context, item));
      }
    }

    return AppWidgets.scaffold(context,
        body: ListView(children: [searchWidget(context), ...tasks]),
        navBar: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            backgroundColor: AppColors.yellow.color,
            fixedColor: AppColors.black.color,
            items: [
              const BottomNavigationBarItem(
                  icon: Icon(Icons.add), label: 'Neu'),
              BottomNavigationBarItem(
                  icon: const Icon(Icons.remove_red_eye),
                  label: showDeleted
                      ? 'Gelöschte verbergen'
                      : 'Gelöschte anzeigen'),
            ],
            onTap: (int id) {
              if (id == 0) {
                Navigator.pushNamed(context, AppRoutes.editTasks.route,
                    arguments: 0);
              } else {
                showDeleted = !showDeleted;
                setState(() {});
              }
            }));
  }
}
