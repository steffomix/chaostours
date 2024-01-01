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

import 'package:chaostours/model/model_task_statistics.dart';
import 'package:chaostours/view/trackpoint/widget_trackpoint_list.dart';
import 'package:flutter/material.dart';

//import 'package:chaostours/logger.dart';
import 'package:chaostours/conf/app_routes.dart';
import 'package:chaostours/view/app_widgets.dart';
import 'package:chaostours/model/model_task.dart';
import 'package:chaostours/model/model_task_group.dart';
import 'package:chaostours/util.dart' as util;
import 'package:flutter/services.dart';

class WidgetTaskEdit extends StatefulWidget {
  const WidgetTaskEdit({super.key});

  @override
  State<WidgetTaskEdit> createState() => _WidgetTaskEdit();
}

class _WidgetTaskEdit extends State<WidgetTaskEdit> {
  //static final Logger logger = Logger.logger<WidgetTaskEdit>();

  static const double _paddingSide = 10.0;

  TextEditingController? _titleController;
  TextEditingController? _notesController;
  TextEditingController? _sortController;

  final _titleUndoController = UndoHistoryController();
  final _notesUndoController = UndoHistoryController();
  final _sortUndoController = UndoHistoryController();

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

  void statistics(
      {required ModelTaskStatistics stats, required ModelTask model}) {
    AppWidgets.dialog(
        isDismissible: true,
        context: context,
        title: const Text('Statistics'),
        contents: [
          SingleChildScrollView(
              controller: ScrollController(),
              scrollDirection: Axis.horizontal,
              child: DataTable(showBottomBorder: true, columns: const [
                DataColumn(label: SizedBox.shrink()),
                DataColumn(label: Text(''))
              ], rows: [
                DataRow(cells: [
                  const DataCell(Text('First Trackpoint')),
                  DataCell(Text(util.formatDate(stats.firstVisited)))
                ]),
                DataRow(cells: [
                  const DataCell(Text('Last Trackpoint')),
                  DataCell(Text(util.formatDate(stats.lastVisited)))
                ]),
                DataRow(cells: [
                  const DataCell(Text('Count Trackpoints')),
                  DataCell(Text(stats.count.toString()))
                ]),
                DataRow(cells: [
                  const DataCell(Text('Duration Min.')),
                  DataCell(Text(util.formatDuration(stats.durationMin)))
                ]),
                DataRow(cells: [
                  const DataCell(Text('Duration Max.')),
                  DataCell(Text(util.formatDuration(stats.durationMax)))
                ]),
                DataRow(cells: [
                  const DataCell(Text('Duration Total')),
                  DataCell(Text(util.formatDuration(stats.durationTotal)))
                ]),
              ]))
        ],
        buttons: [
          TextButton(
            child: const Icon(Icons.copy),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: '''
Task; ${model.title}

First Trackpoint; ${util.formatDate(stats.firstVisited)}
Last Trackpoint; ${util.formatDate(stats.lastVisited)}
Count Trackpoints; ${stats.count}

Min. Duration; ${util.formatDuration(stats.durationMin)}
Max. Duration; ${util.formatDuration(stats.durationMax)}
Duration Total; ${util.formatDuration(stats.durationTotal)}

Task Description; ${model.description}
'''));
              Navigator.pop(context);
            },
          ),
          TextButton(
            child: const Text('OK'),
            onPressed: () {
              Navigator.pop(context);
            },
          )
        ]);
  }

  Widget renderBody() {
    return ListView(children: [
      /// Trackpoints button
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton(
              onPressed: () => Navigator.pushNamed(
                  context, AppRoutes.listTrackpoints.route,
                  arguments: argumentsTrackpointTaskList(_model!.id)),
              child: const Text('Task Trackpoints')),
          ElevatedButton(
              onPressed: () async {
                var model = await ModelTaskStatistics.statistics(_model!);
                statistics(stats: model, model: _model!);
              },
              child: const Text('Task Statistics'))
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
                decoration: const InputDecoration(label: Text('Task')),
                onChanged: ((value) {
                  _model?.title = value;
                  _model?.update();
                }),
                minLines: 1,
                maxLines: 5,
                controller: _titleController ??=
                    TextEditingController(text: _model?.title),
                undoController: _titleUndoController,
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
                onChanged: (val) {
                  _model?.description = val;
                  _model?.update();
                },
                controller: _notesController ??=
                    TextEditingController(text: _model?.description),
                undoController: _notesUndoController,
              ))),

      // groups
      Padding(
          padding: const EdgeInsets.all(_paddingSide),
          child: ListTile(
            trailing: IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {
                  Navigator.pushNamed(
                          context, AppRoutes.listTaskGroupsFromTask.route,
                          arguments: _model?.id)
                      .then(
                    (value) {
                      render();
                    },
                  );
                }),
            title: const Text('Groups', style: TextStyle(height: 2)),
            subtitle: Column(
                children: _groups.map(
              (model) {
                return ElevatedButton(
                  child: ListTile(
                    title: Text(model.title),
                    subtitle: Text(model.description),
                  ),
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.editTaskGroup.route,
                            arguments: model.id)
                        .then(
                      (value) => render(),
                    );
                  },
                );
              },
              // ignore: unnecessary_to_list_in_spreads
            ).toList()),
          )),

      AppWidgets.divider(),

      /// isSelectable
      ListTile(
          title: const Text('Selectable'),
          subtitle: const Text(
            'If checked this group appears in Live Tracking lists.',
            softWrap: true,
          ),
          leading: AppWidgets.checkbox(
            value: _model?.isSelectable ?? false,
            onChanged: (val) async {
              _model?.isSelectable = val ?? false;
              await _model?.update();
            },
          )),

      /// isPreselected
      ListTile(
          title: const Text('Preselected'),
          subtitle: const Text(
            'If checked this group is already selected in Live Tracking lists.\n '
            'However, you can always uncheck preselected tasks in Live Tracking view.',
            softWrap: true,
          ),
          leading: AppWidgets.checkbox(
            value: _model?.isActive ?? false,
            onChanged: (val) async {
              _model?.isPreselected = val ?? false;
              await _model?.update();
            },
          )),

      AppWidgets.divider(),

      /// sort order
      Container(
          padding: const EdgeInsets.all(10),
          child: ValueListenableBuilder<UndoHistoryValue>(
              valueListenable: _notesUndoController,
              builder: (context, value, child) {
                return TextField(
                  decoration: const InputDecoration(label: Text('Sort order')),
                  onChanged: (val) async {
                    _model?.sortOrder = val;
                    await _model?.update();
                  },
                  controller: _sortController ??=
                      TextEditingController(text: _model?.sortOrder),
                  undoController: _sortUndoController,
                );
              })),
      AppWidgets.divider(),

      /// deleted
      ListTile(
          title: const Text('Active'),
          subtitle:
              const Text('Defines if this Task is visible and used or not.'),
          leading: AppWidgets.checkbox(
            value: _model?.isActive ?? false,
            onChanged: (val) async {
              _model?.isActive = val ?? false;
              await _model?.update();
            },
          ))
    ]);
  }
}
