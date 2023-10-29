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

///
import 'package:chaostours/view/app_widgets.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/model/model_task_group.dart';
import 'package:chaostours/conf/app_routes.dart';

class WidgetTaskGroupEdit extends StatefulWidget {
  const WidgetTaskGroupEdit({super.key});

  @override
  State<WidgetTaskGroupEdit> createState() => _WidgetTaskGroupEdit();
}

class _WidgetTaskGroupEdit extends State<WidgetTaskGroupEdit> {
  // ignore: unused_field
  static final Logger logger = Logger.logger<WidgetTaskGroupEdit>();
  ModelTaskGroup? _modelTask;
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void dispose() {
    super.dispose();
  }

  void render() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<ModelTaskGroup> createTaskGroup() async {
    var count = await ModelTaskGroup.count();
    var model = ModelTaskGroup(title: '#${count + 1}');
    await ModelTaskGroup.insert(model);
    return model;
  }

  Future<ModelTaskGroup?> loadTaskGroup(int? id) async {
    if (id == null) {
      return await createTaskGroup();
    }
    var model = await ModelTaskGroup.byId(id);
    if (model == null) {
      if (mounted) {
        Navigator.pop(context);
      }
      return null;
    }
    return model;
  }

  @override
  Widget build(BuildContext context) {
    int? id = ModalRoute.of(context)?.settings.arguments as int?;

    return FutureBuilder<ModelTaskGroup?>(
      future: loadTaskGroup(id),
      builder: (context, snapshot) {
        Widget? loading = AppWidgets.checkSnapshot(snapshot);
        if (loading != null) {
          return AppWidgets.scaffold(context,
              body: AppWidgets.loading('Loading Group...'));
        }
        var model = snapshot.data!;
        return body(model);
      },
    );
  }

  Widget body(ModelTaskGroup model) {
    _modelTask = model;
    _titleController.text = model.title;
    _notesController.text = model.description;
    return scaffold(editGroup(model));
  }

  Widget scaffold(Widget body) {
    return AppWidgets.scaffold(context,
        title: 'Edit Task Group',
        navBar: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.add), label: 'Neu'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.cancel), label: 'Abbrechen'),
            ],
            onTap: (int id) async {
              if (id == 0) {
                Navigator.pushNamed(context, AppRoutes.taskGroupEdit.route)
                    .then((_) {
                  render();
                });
              } else if (id == 1) {
                Navigator.pop(context);
              }
            }),
        body: body);
  }

  Widget editGroup(ModelTaskGroup model) {
    return ListView(children: [
      /// taskname
      Container(
          padding: const EdgeInsets.all(10),
          child: TextField(
            decoration: const InputDecoration(label: Text('Task Group Name')),
            onChanged: ((value) {
              model.title = value;
              model.update();
            }),
            maxLines: 3,
            minLines: 3,
            controller: _titleController,
          )),
      AppWidgets.divider(),

      /// notes
      Container(
          padding: const EdgeInsets.all(10),
          child: TextField(
            keyboardType: TextInputType.multiline,
            decoration: const InputDecoration(label: Text('Notizen')),
            maxLines: null,
            minLines: 3,
            controller: _notesController,
            onChanged: (value) {
              model.description = value.trim();
              model.update();
            },
          )),
      AppWidgets.divider(),

      /// deleted
      ListTile(
          title: const Text('Deaktiviert / gelöscht'),
          subtitle: const Text(
            'Wenn deaktiviert bzw. gelöscht, wird dieser Task behandelt wie ein "gelöschter" Fakebook Account.',
            softWrap: true,
          ),
          leading: Checkbox(
            value: model.isActive,
            onChanged: (val) {
              model.isActive = val ?? false;
              model.update().then((value) => render());
            },
          )),

      AppWidgets.divider(),

      ElevatedButton(
        child: const Text('Show Tasks from this group'),
        onPressed: () => Navigator.pushNamed(
                context, AppRoutes.tasksFromTaskGroupList.route,
                arguments: _modelTask?.id)
            .then((value) {
          render();
        }),
      )
    ]);
  }
}
