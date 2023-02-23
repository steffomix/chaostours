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

  bool? _deleted;
  ModelTask? _task;
  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final id = ModalRoute.of(context)!.settings.arguments as int;
    bool create = id <= 0;
    _task ??= create
        ? ModelTask(task: '', deleted: false, notes: '')
        : ModelTask.getTask(id);
    var task = _task!;
    _deleted ??= task.deleted;

    var deleted = _deleted!;

    return AppWidgets.scaffold(context,
        body: ListView(children: [
          ///
          /// ok/add button
          Center(
              child: IconButton(
            icon: Icon(create ? Icons.add : Icons.done, size: 50),
            onPressed: () {
              if (task.task.isEmpty) {
                task.task = 'Person #${task.id}';
              }
              task.deleted = deleted;
              create ? ModelTask.insert(task) : ModelTask.write();
              Navigator.pop(context);
            },
          )),

          /// taskname
          Container(
              padding: const EdgeInsets.all(10),
              child: TextField(
                decoration: const InputDecoration(label: Text('Aufgabe')),
                onChanged: ((value) {
                  task.task = value;
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
                  setState(() {
                    _deleted = val;
                  });
                  task.deleted = val ?? false;
                },
              ))
        ]));
  }
}
