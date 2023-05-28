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

///
import 'package:chaostours/logger.dart';
import 'package:chaostours/conf/app_routes.dart';
import 'package:chaostours/model/model_task.dart';

enum _DisplayMode {
  list,
  sort;
}

class WidgetTaskList extends StatefulWidget {
  const WidgetTaskList({super.key});

  @override
  State<WidgetTaskList> createState() => _WidgetTaskList();
}

class _WidgetTaskList extends State<WidgetTaskList> {
  // ignore: unused_field
  static final Logger logger = Logger.logger<WidgetTaskList>();

  bool showDeleted = false;
  String search = '';
  TextEditingController controller = TextEditingController();
  _DisplayMode displayMode = _DisplayMode.list;

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

  Widget sortWidget(BuildContext context) {
    var list = ModelTask.getAll();
    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (context, index) {
        var model = list[index];
        return ListTile(
            leading: IconButton(
                icon: const Icon(Icons.arrow_downward),
                onPressed: () {
                  if (index < list.length - 1) {
                    list[index + 1].sortOrder--;
                    list[index].sortOrder++;
                  }
                  ModelTask.write().then((_) => setState(() {}));
                }),
            trailing: IconButton(
              icon: const Icon(Icons.arrow_upward),
              onPressed: () {
                if (index > 0) {
                  list[index - 1].sortOrder++;
                  list[index].sortOrder--;
                }
                ModelTask.write().then((_) => setState(() {}));
              },
            ),
            title: Text(model.task,
                style: model.deleted
                    ? const TextStyle(decoration: TextDecoration.lineThrough)
                    : null),
            subtitle: Text(model.notes));
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
        body: displayMode == _DisplayMode.list
            ? ListView(children: [searchWidget(context), ...tasks])
            : sortWidget(context),
        appBar: AppBar(title: const Text('Aufgaben Liste')),
        navBar: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            items: [
              const BottomNavigationBarItem(
                  icon: Icon(Icons.add), label: 'Neu'),
              displayMode == _DisplayMode.list
                  ? const BottomNavigationBarItem(
                      icon: Icon(Icons.sort), label: 'Sortieren')
                  : const BottomNavigationBarItem(
                      icon: Icon(Icons.list), label: 'Liste'),
              BottomNavigationBarItem(
                  icon: Icon(showDeleted || displayMode == _DisplayMode.sort
                      ? Icons.delete
                      : Icons.remove_red_eye),
                  label: showDeleted || displayMode == _DisplayMode.sort
                      ? 'Verb. Gel.'
                      : 'Zeige Gel.'),
            ],
            onTap: (int id) {
              if (id == 0) {
                Navigator.pushNamed(context, AppRoutes.editTasks.route,
                    arguments: 0);
              }
              if (id == 2) {
                showDeleted = !showDeleted;
                setState(() {});
              }
              if (id == 1) {
                displayMode = displayMode == _DisplayMode.list
                    ? _DisplayMode.sort
                    : _DisplayMode.list;
                setState(() {});
              }
            }));
  }
}
