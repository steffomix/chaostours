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

import 'package:chaostours/statistics/user_statistics.dart';
import 'package:chaostours/view/trackpoint/widget_trackpoint_list.dart';
import 'package:flutter/material.dart';

///
import 'package:chaostours/logger.dart';
import 'package:chaostours/conf/app_routes.dart';
import 'package:chaostours/view/system/app_widgets.dart';
import 'package:chaostours/model/model_user_group.dart';

class WidgetUserGroupEdit extends StatefulWidget {
  const WidgetUserGroupEdit({super.key});

  @override
  State<WidgetUserGroupEdit> createState() => _WidgetUserGroupEdit();
}

class _WidgetUserGroupEdit extends State<WidgetUserGroupEdit> {
  // ignore: unused_field
  static final Logger logger = Logger.logger<WidgetUserGroupEdit>();
  ModelUserGroup? _model;

  int _countUser = 0;

  final _titleController = TextEditingController();
  final _titleUndoController = UndoHistoryController();

  final _notesController = TextEditingController();
  final _notesUndoController = UndoHistoryController();

  @override
  void dispose() {
    super.dispose();
  }

  void render() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<ModelUserGroup?> loadUserGroup(int? id) async {
    if (id == null) {
      Future.microtask(() => Navigator.pop(context));
      return null;
    } else {
      _model = await ModelUserGroup.byId(id);
    }
    if (_model == null) {
      if (mounted) {
        Future.microtask(() => Navigator.pop(context));
      }
      throw 'Group #$id not found';
    } else {
      _countUser = await _model!.userCount();
      return _model;
    }
  }

  @override
  Widget build(BuildContext context) {
    int? id = ModalRoute.of(context)?.settings.arguments as int?;
    return FutureBuilder<ModelUserGroup?>(
      initialData: _model,
      future: loadUserGroup(id),
      builder: (context, snapshot) {
        return AppWidgets.checkSnapshot(context, snapshot) ??
            body(snapshot.data!);
      },
    );
  }

  Widget body(ModelUserGroup model) {
    _model = model;
    _titleController.text = _model?.title ?? '';
    _notesController.text = _model?.description ?? '';
    return scaffold(renderBody());
  }

  Widget scaffold(Widget body) {
    return AppWidgets.scaffold(context,
        title: 'Edit User Group',
        body: body,
        navBar: AppWidgets.navBarCreateItem(context, name: 'User Group',
            onCreate: () async {
          final model = await AppWidgets.createUserGroup(context);
          if (model != null && mounted) {
            await Navigator.pushNamed(context, AppRoutes.editUserGroup.route,
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
                      arguments: TrackpointListArguments.userGroup
                          .arguments(_model!.id)),
                  child: const Text('Trackpoints'))),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: FilledButton(
                  onPressed: () async {
                    var stats = await UserStatistics.groupStatistics(_model!);

                    if (mounted) {
                      AppWidgets.statistics(context, stats: stats,
                          reload: (DateTime start, DateTime end) async {
                        return await UserStatistics.groupStatistics(stats.model,
                            start: start, end: end);
                      });
                    }
                  },
                  child: const Text('Statistics')))
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
                decoration:
                    const InputDecoration(label: Text('User Group Name')),
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
            onChanged: (val) async {
              _model?.isSelectable = val ?? false;
              await _model?.update();
            },
          )),

      AppWidgets.divider(),

      /// isPreselected
      ListTile(
          title: const Text('Preselected'),
          subtitle: const Text(
              'If checked this group is already selected in Live Tracking lists.'),
          leading: AppWidgets.checkbox(
            value: _model?.isPreselected ?? false,
            onChanged: (val) async {
              _model?.isPreselected = val ?? false;
              await _model?.update();
            },
          )),

      AppWidgets.divider(),

      FilledButton(
          child: Text('Show $_countUser Users from this group'),
          onPressed: () async {
            await Navigator.pushNamed(
                context, AppRoutes.listUsersFromUserGroup.route,
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
