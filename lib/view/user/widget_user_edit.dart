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
import 'package:chaostours/statistics/user_statistics.dart';
import 'package:chaostours/view/trackpoint/widget_trackpoint_list.dart';
import 'package:chaostours/conf/app_routes.dart';
import 'package:chaostours/view/app_widgets.dart';
import 'package:chaostours/model/model_user.dart';
import 'package:chaostours/model/model_user_group.dart';

class WidgetUserEdit extends StatefulWidget {
  const WidgetUserEdit({super.key});

  @override
  State<WidgetUserEdit> createState() => _WidgetUserEdit();
}

class _WidgetUserEdit extends State<WidgetUserEdit> {
  //static final Logger logger = Logger.logger<WidgetUserEdit>();

  static const double _paddingSide = 10.0;

  ModelUser? _model;
  List<ModelUserGroup> _groups = [];

  TextEditingController? _titleController;
  TextEditingController? _notesController;
  TextEditingController? _sortController;
  TextEditingController? _phoneController;
  TextEditingController? _addressController;

  final _titleUndoController = UndoHistoryController();
  final _notesUndoController = UndoHistoryController();
  final _sortUndoController = UndoHistoryController();
  final _phoneUndoController = UndoHistoryController();
  final _addressUndoController = UndoHistoryController();

  void render() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<ModelUser?> loadUser(int id) async {
    var model = await ModelUser.byId(id);

    var ids = (await model?.groupIds()) ?? [];
    _groups = ids.isEmpty ? [] : await ModelUserGroup.byIdList(ids);
    return model;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ModelUser?>(
        future:
            loadUser(ModalRoute.of(context)?.settings.arguments as int? ?? 0),
        builder: (context, snapshot) {
          return AppWidgets.checkSnapshot(context, snapshot,
                  build: (context, data) => _model = data) ??
              AppWidgets.scaffold(context,
                  body: renderBody(),
                  navBar: AppWidgets.navBarCreateItem(context, name: 'User',
                      onCreate: () async {
                    var count = (await ModelUser.count()) + 1;
                    var model = await ModelUser(title: '#$count').insert();
                    if (mounted) {
                      await Navigator.pushNamed(
                          context, AppRoutes.editUser.route,
                          arguments: model.id);
                      render();
                    }
                  }));
        });
  }

  Widget renderBody() {
    return ListView(children: [
      /// Trackpoints button
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FilledButton(
              onPressed: () => Navigator.pushNamed(
                  context, AppRoutes.listTrackpoints.route,
                  arguments: argumentsTrackpointAliasList(_model!.id)),
              child: const Text('User Trackpoints')),
          FilledButton(
              onPressed: () async {
                var stats = await UserStatistics.statistics(_model!);

                if (mounted) {
                  AppWidgets.statistics(context, stats: stats,
                      reload: (DateTime start, DateTime end) async {
                    return await UserStatistics.statistics(stats.model,
                        start: start, end: end);
                  });
                }
              },
              child: const Text('User Statistics'))
        ],
      ),

      /// username
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
                decoration: const InputDecoration(label: Text('User')),
                onChanged: ((value) {
                  _model?.title = value;
                  _model?.update();
                }),
                minLines: 1,
                maxLines: 5,
                undoController: _titleUndoController,
                controller: _titleController ??=
                    TextEditingController(text: _model?.title),
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

      /// phone
      ListTile(
          dense: true,
          trailing: ValueListenableBuilder<UndoHistoryValue>(
            valueListenable: _phoneUndoController,
            builder: (context, value, child) {
              return IconButton(
                icon: const Icon(Icons.undo),
                onPressed: value.canUndo
                    ? () {
                        _phoneUndoController.undo();
                      }
                    : null,
              );
            },
          ),
          title: Container(
              padding: const EdgeInsets.all(10),
              child: TextField(
                decoration: const InputDecoration(label: Text('Phone')),
                onChanged: (val) {
                  _model?.phone = val;
                  _model?.update();
                },
                controller: _phoneController ??=
                    TextEditingController(text: _model?.phone),
                undoController: _phoneUndoController,
              ))),

      /// address
      ListTile(
          dense: true,
          trailing: ValueListenableBuilder<UndoHistoryValue>(
            valueListenable: _addressUndoController,
            builder: (context, value, child) {
              return IconButton(
                icon: const Icon(Icons.undo),
                onPressed: value.canUndo
                    ? () {
                        _addressUndoController.undo();
                      }
                    : null,
              );
            },
          ),
          title: Container(
              padding: const EdgeInsets.all(10),
              child: TextField(
                decoration: const InputDecoration(label: Text('Address')),
                maxLines: null,
                minLines: 5,
                onChanged: (val) {
                  _model?.address = val;
                  _model?.update();
                },
                controller: _addressController ??=
                    TextEditingController(text: _model?.address),
                undoController: _addressUndoController,
              ))),

      AppWidgets.divider(),

      // groups
      Padding(
          padding: const EdgeInsets.all(_paddingSide),
          child: ListTile(
            trailing: IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {
                  Navigator.pushNamed(
                          context, AppRoutes.listUserGroupsFromUser.route,
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
                return FilledButton(
                  child: ListTile(
                    title: Text(model.title),
                    subtitle: Text(model.description),
                  ),
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.editUserGroup.route,
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
          onChanged: (state) async {
            _model?.isSelectable = state ?? false;
            await _model?.update();
          },
        ),
      ),

      /// isPreselected
      ListTile(
          title: const Text('Preselected'),
          subtitle: const Text(
            'If checked this group is already selected in Live Tracking lists.\n '
            'However, you can always uncheck preselected tasks in Live Tracking view.',
            softWrap: true,
          ),
          leading: AppWidgets.checkbox(
            value: _model?.isPreselected ?? false,
            onChanged: (val) async {
              _model?.isPreselected = val ?? false;
              await _model?.update();
            },
          )),

      AppWidgets.divider(),

      /// sort order
      ListTile(
          dense: true,
          trailing: ValueListenableBuilder<UndoHistoryValue>(
            valueListenable: _sortUndoController,
            builder: (context, value, child) {
              return IconButton(
                icon: const Icon(Icons.undo),
                onPressed: value.canUndo
                    ? () {
                        _sortUndoController.undo();
                      }
                    : null,
              );
            },
          ),
          title: Container(
              padding: const EdgeInsets.all(10),
              child: TextField(
                decoration: const InputDecoration(label: Text('Sort order')),
                onChanged: (val) async {
                  _model?.sortOrder = val;
                  await _model?.update();
                },
                controller: _sortController ??=
                    TextEditingController(text: _model?.sortOrder),
                undoController: _sortUndoController,
              ))),

      AppWidgets.divider(),

      /// deleted
      ListTile(
          title: const Text('Active'),
          subtitle:
              const Text('Defines if this User is visible and used or not.'),
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
