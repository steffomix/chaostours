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

import 'package:chaostours/conf/app_routes.dart';
import 'package:chaostours/model/model_task_group.dart';
import 'package:flutter/material.dart';

//import 'package:chaostours/logger.dart';
import 'package:chaostours/view/app_widgets.dart';
import 'package:chaostours/model/model_task.dart';

class WidgetTaskEdit extends StatefulWidget {
  const WidgetTaskEdit({super.key});

  @override
  State<WidgetTaskEdit> createState() => _WidgetTaskEdit();
}

class _WidgetTaskEdit extends State<WidgetTaskEdit> {
  //static final Logger logger = Logger.logger<WidgetTaskEdit>();

  ModelTask? _model;
  List<ModelTaskGroup> _groups = [];

  void render() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<ModelTask?> loadTask(int? id) async {
    var model = await ModelTask.byId(id ?? 0);
    if (model == null) {
      if (mounted) {
        Navigator.pop(context);
      }
    }
    var ids = (await model?.groupIds()) ?? [];
    _groups = ids.isEmpty ? [] : await ModelTaskGroup.byIdList(ids);
    return model;
  }

  @override
  Widget build(BuildContext context) {
    final id = ModalRoute.of(context)?.settings.arguments as int?;

    return FutureBuilder<ModelTask?>(
      future: loadTask(id),
      builder: (context, snapshot) {
        return AppWidgets.checkSnapshot(snapshot) ??
            AppWidgets.scaffold(
              context,
              body: renderBody(snapshot.data!),
              appBar: AppBar(title: const Text('Edit Task')),
            );
      },
    );
  }

  Widget renderBody(ModelTask model) {
    _model = model;
    return ListView(children: [
      /// taskname
      Container(
          padding: const EdgeInsets.all(10),
          child: TextField(
            decoration: const InputDecoration(label: Text('Task')),
            onChanged: ((value) {
              _model?.title = value;
              _model?.update();
            }),
            minLines: 1,
            maxLines: 5,
            controller: TextEditingController(text: _model?.title),
          )),

      /// notes
      Container(
          padding: const EdgeInsets.all(10),
          child: TextField(
            decoration: const InputDecoration(label: Text('Notes')),
            maxLines: null,
            minLines: 5,
            controller: TextEditingController(text: _model?.description),
            onChanged: (val) {
              _model?.description = val;
              _model?.update();
            },
          )),

      // groups
      Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: ElevatedButton(
              child: Column(children: [
                const Text('Groups', style: TextStyle(height: 2)),
                ..._groups.map(
                  (model) {
                    return ListTile(
                      title: Text(
                        model.title,
                      ),
                      subtitle: Text(model.description),
                    );
                  },
                ).toList()
              ]),
              onPressed: () {
                Navigator.pushNamed(
                        context, AppRoutes.taskGroupsFromTaskList.route,
                        arguments: _model?.id)
                    .then(
                  (value) {
                    render();
                  },
                );
              })),

      AppWidgets.divider(),

      /// deleted
      ListTile(
          title: const Text('Active'),
          subtitle:
              const Text('Defines if this Task is visible and used or not.'),
          leading: Checkbox(
            value: _model?.isActive ?? false,
            onChanged: (val) {
              _model?.isActive = val ?? false;
              _model?.update().then(
                (value) {
                  render();
                },
              );
            },
          ))
    ]);
  }
}
