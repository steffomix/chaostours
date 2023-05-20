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

import 'package:chaostours/view/app_widgets.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

///
import 'package:chaostours/logger.dart';
import 'package:chaostours/model/model_task.dart';

class WidgetTaskEdit extends StatefulWidget {
  const WidgetTaskEdit({super.key});

  @override
  State<WidgetTaskEdit> createState() => _WidgetTaskEdit();
}

class _WidgetTaskEdit extends State<WidgetTaskEdit> {
  // ignore: unused_field
  static final Logger logger = Logger.logger<WidgetTaskEdit>();

  ValueNotifier<bool> modified = ValueNotifier<bool>(false);
  //TextEditingController nameController = TextEditingController();
  //TextEditingController notesController = TextEditingController();

  late ModelTask task;
  int taskId = 0;
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
    if (!_initialized) {
      taskId = (ModalRoute.of(context)?.settings.arguments ?? 0) as int;
      if (taskId > 0) {
        task = ModelTask.getTask(taskId).clone();
      } else {
        task = ModelTask(task: '', notes: '');
      }
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
            onTap: (int tapId) {
              if (tapId == 0 && modified.value) {
                if (taskId == 0) {
                  ModelTask.insert(task).then((id) {
                    if (task.task.trim().isEmpty) {
                      task.task = '#$id';
                    }
                    Navigator.pop(context);
                    Fluttertoast.showToast(msg: 'Task created');
                  });
                } else {
                  ModelTask.update(task).then((_) {
                    Navigator.pop(context);
                    Fluttertoast.showToast(msg: 'Task updated');
                  });
                }
              } else if (tapId == 1) {
                Navigator.pop(context);
              }
            }),
        body: ListView(children: [
          /// taskname
          Container(
              padding: const EdgeInsets.all(10),
              child: TextField(
                decoration: const InputDecoration(label: Text('Arbeit')),
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
                'Definiert ob diese Arbeit sichtbar ist. '
                '\nBereits zugewiesene Arbeiten bleiben grundsätzlich sichtbar.',
                softWrap: true,
              ),
              leading: Checkbox(
                value: task.deleted,
                onChanged: (val) {
                  task.deleted = val ?? false;
                  modify();
                  setState(() {});
                },
              ))
        ]));
  }
}
