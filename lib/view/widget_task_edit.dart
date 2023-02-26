import 'package:chaostours/view/app_widgets.dart';
import 'package:flutter/material.dart';

///
import 'package:chaostours/logger.dart';
import 'package:chaostours/model/model_task.dart';

class WidgetTaskEdit extends StatefulWidget {
  const WidgetTaskEdit({super.key});

  @override
  State<WidgetTaskEdit> createState() => _WidgetTaskEdit();
}

class _WidgetTaskEdit extends State<WidgetTaskEdit> {
  static final Logger logger = Logger.logger<WidgetTaskEdit>();

  ValueNotifier<bool> modified = ValueNotifier<bool>(false);
  //TextEditingController nameController = TextEditingController();
  //TextEditingController notesController = TextEditingController();

  late bool? deleted;
  late bool create;
  late ModelTask task;
  bool _initialized = false;
  @override
  void dispose() {
    super.dispose();
  }

  void modify() {
    modified.value = true;
  }

  @override
  Widget build(BuildContext context) {
    final id = (ModalRoute.of(context)?.settings.arguments ?? 0) as int;
    if (!_initialized) {
      create = id <= 0;
      task = create
          ? ModelTask(task: '', deleted: false, notes: '')
          : ModelTask.getTask(id).clone();
      deleted = task.deleted;
      _initialized = true;
    }

    return AppWidgets.scaffold(context,
        navBar: BottomNavigationBar(
            fixedColor: AppColors.black.color,
            type: BottomNavigationBarType.fixed,
            backgroundColor: AppColors.yellow.color,
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
            onTap: (int id) {
              if (id == 0) {
                if (create) {
                  if (task.task.trim().isEmpty) {
                    task.task = 'Aufgabe #${ModelTask.length + 1}';
                  }
                  ModelTask.insert(task).then((_) {
                    AppWidgets.navigate(context, AppRoutes.listTasks);
                  });
                } else {
                  ModelTask.update(task).then((_) {
                    AppWidgets.navigate(context, AppRoutes.listTasks);
                  });
                }
              } else if (id == 1) {
                Navigator.pop(context);
              }
            }),
        body: ListView(children: [
          /// taskname
          Container(
              padding: const EdgeInsets.all(10),
              child: TextField(
                decoration: const InputDecoration(label: Text('Aufgabe')),
                onChanged: ((value) {
                  task.task = value;
                  modify();
                }),
                maxLines: 1,
                minLines: 1,
                controller: TextEditingController(text: task.task),
              )),

          /// notes
          Container(
              padding: const EdgeInsets.all(10),
              child: TextField(
                decoration: const InputDecoration(label: Text('Notizen')),
                maxLines: null,
                minLines: 3,
                controller: TextEditingController(text: task.notes),
                onChanged: (val) {
                  task.notes = val;
                  modify();
                },
              )),

          /// deleted
          ListTile(
              title: const Text('Deaktiviert'),
              subtitle: const Text(
                'Definiert ob diese Aufgabe sichtbar ist. '
                '\nBereits zugewiesene Aufgaben bleiben grundsätzlich sichtbar.',
                softWrap: true,
              ),
              leading: Checkbox(
                value: deleted,
                onChanged: (val) {
                  task.deleted = val ?? false;
                  deleted = task.deleted;
                  modify();
                  setState(() {});
                },
              ))
        ]));
  }
}
