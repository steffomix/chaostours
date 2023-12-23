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

//import 'package:chaostours/logger.dart';
import 'package:chaostours/conf/app_routes.dart';
import 'package:chaostours/view/app_widgets.dart';
import 'package:chaostours/model/model_task.dart';
import 'package:chaostours/model/model_task_group.dart';

class WidgetTaskEdit extends StatefulWidget {
  const WidgetTaskEdit({super.key});

  @override
  State<WidgetTaskEdit> createState() => _WidgetTaskEdit();
}

class _WidgetTaskEdit extends State<WidgetTaskEdit> {
  //static final Logger logger = Logger.logger<WidgetTaskEdit>();

  final _titleController = TextEditingController();
  final _titleUndoController = UndoHistoryController();

  final _notesController = TextEditingController();
  final _notesUndoController = UndoHistoryController();

  ModelTask? _model;
  List<ModelTaskGroup> _groups = [];

  void render() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<ModelTask?> loadTask(int id) async {
    var model = await ModelTask.byId(id);

    var ids = (await model?.groupIds()) ?? [];
    _groups = ids.isEmpty ? [] : await ModelTaskGroup.byIdList(ids);
    return model;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ModelTask?>(
        initialData: _model,
        future:
            loadTask(ModalRoute.of(context)?.settings.arguments as int? ?? 0),
        builder: (context, snapshot) {
          return AppWidgets.checkSnapshot(context, snapshot,
                  build: (context, data) => _model = data) ??
              AppWidgets.scaffold(context,
                  body: renderBody(),
                  navBar: AppWidgets.navBarCreateItem(context, name: 'Task',
                      onCreate: () async {
                    var count = (await ModelTask.count()) + 1;
                    var model = await ModelTask(title: '#$count').insert();
                    if (mounted) {
                      await Navigator.pushNamed(
                          context, AppRoutes.editTask.route,
                          arguments: model.id);
                      render();
                    }
                  }));
        });
  }

  Widget renderBody() {
    return ListView(children: [
      /// taskname
      ListTile(
          dense: true,
          trailing: ValueListenableBuilder<UndoHistoryValue>(
            valueListenable: _titleUndoController,
            builder: (context, value, child) {
              return IconButton(
                icon: const Icon(Icons.undo),
                onPressed: value.canUndo
                    ? () {
                        _titleUndoController.undo();
                      }
                    : null,
              );
            },
          ),
          title: Container(
              padding: const EdgeInsets.all(10),
              child: TextField(
                decoration: const InputDecoration(label: Text('Task')),
                onChanged: ((value) {
                  _model?.title = value;
                  _model?.update();
                }),
                minLines: 1,
                maxLines: 5,
                controller: _titleController,
              ))),

      /// notes
      ListTile(
          dense: true,
          trailing: ValueListenableBuilder<UndoHistoryValue>(
            valueListenable: _notesUndoController,
            builder: (context, value, child) {
              return IconButton(
                icon: const Icon(Icons.undo),
                onPressed: value.canUndo
                    ? () {
                        _notesUndoController.undo();
                      }
                    : null,
              );
            },
          ),
          title: Container(
              padding: const EdgeInsets.all(10),
              child: TextField(
                decoration: const InputDecoration(label: Text('Notes')),
                maxLines: null,
                minLines: 5,
                controller: _notesController,
                onChanged: (val) {
                  _model?.description = val;
                  _model?.update();
                },
              ))),

      /// isSelectable
      ListTile(
          title: const Text('Selectable'),
          subtitle: const Text(
            'If checked this group appears in Live Tracking lists',
            softWrap: true,
          ),
          leading: Checkbox(
            value: _model?.isSelectable ?? false,
            onChanged: (val) {
              _model?.isSelectable = val ?? false;
              _model?.update().then((value) => render());
            },
          )),

      AppWidgets.divider(),

      /// isPreselected
      ListTile(
          title: const Text('Preselected'),
          subtitle: const Text(
            'If checked this group is already selected in Live Tracking lists.\n '
            'However, you can always uncheck preselected tasks.',
            softWrap: true,
          ),
          leading: Checkbox(
            value: _model?.isActive ?? false,
            onChanged: (val) {
              _model?.isActive = val ?? false;
              _model?.update().then((value) => render());
            },
          )),

      AppWidgets.divider(),

      /// sort order
      Container(
          padding: const EdgeInsets.all(10),
          child: TextField(
            decoration: const InputDecoration(label: Text('Sort order')),
            controller: TextEditingController(text: _model?.sortOrder),
            onChanged: (val) {
              _model?.sortOrder = val;
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
                )
              ]),
              onPressed: () {
                Navigator.pushNamed(
                        context, AppRoutes.listTaskGroupsFromTask.route,
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
