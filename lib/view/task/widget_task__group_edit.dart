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

import 'package:chaostours/statistics/task_statistics.dart';
import 'package:chaostours/view/trackpoint/widget_trackpoint_list.dart';
import 'package:flutter/material.dart';

///
import 'package:chaostours/view/system/app_widgets.dart';
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

  int _countTask = 0;

  final _titleController = TextEditingController();
  final _titleUndoController = UndoHistoryController();

  final _notesController = TextEditingController();
  final _notesUndoController = UndoHistoryController();

  ModelTaskGroup? _model;

  @override
  void dispose() {
    super.dispose();
  }

  void render() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<ModelTaskGroup?> loadTaskGroup(int? id) async {
    if (id == null) {
      Future.microtask(() => Navigator.pop(context));
      return null;
    } else {
      _model = await ModelTaskGroup.byId(id);
    }
    if (_model == null) {
      if (mounted) {
        Future.microtask(() => Navigator.pop(context));
      }
      throw 'Group #$id not found';
    } else {
      _countTask = await _model!.taskCount();
      return _model;
    }
  }

  @override
  Widget build(BuildContext context) {
    int? id = ModalRoute.of(context)?.settings.arguments as int?;
    return FutureBuilder<ModelTaskGroup?>(
      initialData: _model,
      future: loadTaskGroup(id),
      builder: (context, snapshot) {
        return AppWidgets.checkSnapshot(context, snapshot) ??
            body(snapshot.data!);
      },
    );
  }

  Widget body(ModelTaskGroup model) {
    _model = model;
    _titleController.text = _model?.title ?? '';
    _notesController.text = _model?.description ?? '';
    return scaffold(renderBody());
  }

  Widget scaffold(Widget body) {
    return AppWidgets.scaffold(context,
        title: 'Edit Task Group',
        body: body,
        navBar: AppWidgets.navBarCreateItem(context, name: 'Task Group',
            onCreate: () async {
          final model = await AppWidgets.createTaskGroup(context);
          if (model != null && mounted) {
            await Navigator.pushNamed(context, AppRoutes.editTaskGroup.route,
                arguments: model.id);
            render();
          }
        }));
  }

  Widget renderBody() {
    return ListView(children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: FilledButton(
                  onPressed: () => Navigator.pushNamed(
                      context, AppRoutes.listTrackpoints.route,
                      arguments: TrackpointListArguments.taskGroup
                          .arguments(_model!.id)),
                  child: const Text('Trackpoints'))),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: FilledButton(
                  onPressed: () async {
                    var stats = await TaskStatistics.statistics(_model!);

                    if (mounted) {
                      AppWidgets.statistics(context, stats: stats,
                          reload: (DateTime start, DateTime end) async {
                        return await TaskStatistics.groupStatistics(stats.model,
                            start: start, end: end);
                      });
                    }
                  },
                  child: const Text('Statistics')))
        ],
      ),

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
                decoration:
                    const InputDecoration(label: Text('Task Group Name')),
                onChanged: ((value) {
                  _model?.title = value;
                  _model?.update();
                }),
                maxLines: 3,
                minLines: 3,
                controller: _titleController,
              ))),
      AppWidgets.divider(),

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
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(label: Text('Notes')),
                maxLines: null,
                minLines: 3,
                controller: _notesController,
                onChanged: (value) {
                  _model?.description = value.trim();
                  _model?.update();
                },
              ))),
      AppWidgets.divider(),

      /// isSelectable
      ListTile(
          title: const Text('Selectable'),
          subtitle: const Text(
            'If checked this group appears in Live Tracking lists',
            softWrap: true,
          ),
          leading: AppWidgets.checkbox(
            value: _model?.isSelectable ?? false,
            onChanged: (val) {
              _model?.isSelectable = val ?? false;
              _model?.update();
            },
          )),

      AppWidgets.divider(),

      /// isPreselected
      ListTile(
          title: const Text('Preselected'),
          subtitle: const Text(
            'If checked this group is already selected in Live Tracking lists.',
            softWrap: true,
          ),
          leading: Checkbox(
            value: _model?.isPreselected ?? false,
            onChanged: (val) {
              _model?.isPreselected = val ?? false;
              _model?.update().then((value) => render());
            },
          )),

      AppWidgets.divider(),

      FilledButton(
          child: Text('Show $_countTask Tasks from this group'),
          onPressed: () async {
            await Navigator.pushNamed(
                context, AppRoutes.listTasksFromTaskGroup.route,
                arguments: _model?.id);
            render();
          }),

      AppWidgets.divider(),

      /// deleted
      ListTile(
          title: const Text('Active'),
          subtitle: const Text('This Group is active and visible'),
          leading: AppWidgets.checkbox(
            value: _model?.isActive ?? false,
            onChanged: (val) {
              _model?.isActive = val ?? false;
              _model?.update();
            },
          )),
    ]);
  }
}
