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
import 'package:chaostours/logger.dart';
import 'package:chaostours/conf/app_routes.dart';
import 'package:chaostours/view/app_widgets.dart';
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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ModelUserGroup?>(
      initialData: _model,
      future: ModelUserGroup.byId(
          ModalRoute.of(context)?.settings.arguments as int? ?? 0),
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
          var count = (await ModelUserGroup.count()) + 1;
          var model = await ModelUserGroup(title: '#$count').insert();
          if (mounted) {
            await Navigator.pushNamed(context, AppRoutes.editUserGroup.route,
                arguments: model.id);
            render();
          }
        }));
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

      ElevatedButton(
          child: const Text('Show Users from this group'),
          onPressed: () async {
            await Navigator.pushNamed(
                context, AppRoutes.listUsersFromUserGroup.route,
                arguments: _model?.id);
            render();
          }),

      AppWidgets.divider(),

      /// deleted
      ListTile(
          title: const Text('Deaktivated'),
          subtitle: const Text(
            'Deaktivated Items have no functionality and appear only in Trash views.',
            softWrap: true,
          ),
          leading: Checkbox(
            value: _model?.isActive ?? false,
            onChanged: (val) {
              _model?.isActive = val ?? false;
              _model?.update().then((value) => render());
            },
          )),
    ]);
  }
}
