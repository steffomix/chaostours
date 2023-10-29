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
import 'package:chaostours/view/app_base_widget.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/conf/app_routes.dart';
import 'package:chaostours/model/model_task_group.dart';
import 'package:chaostours/model/model_task.dart';

class WidgetTaskGroupsFromTaskList extends BaseWidget {
  const WidgetTaskGroupsFromTaskList({super.key});

  @override
  State<WidgetTaskGroupsFromTaskList> createState() =>
      _WidgetTaskGroupsFromTaskList();
}

class _WidgetTaskGroupsFromTaskList
    extends BaseWidgetState<WidgetTaskGroupsFromTaskList> {
  // ignore: unused_field
  static final Logger logger = Logger.logger<WidgetTaskGroupsFromTaskList>();

  int _selectedNavBarItem = 0;

  final TextEditingController _searchTextController = TextEditingController();
  final List<Widget> _loadedWidgets = [];
  ModelTask? _model;
  List<int>? _ids;
  // items per page
  int getLimit() => 30;

  @override
  Future<void> initialize(BuildContext context, Object? args) async {
    _model = await ModelTask.byId(args as int);
    _ids ??= await _model?.groupIds() ?? [];
  }

  @override
  Future<int> loadItems({required int offset, int limit = 20}) async {
    var newItems = await ModelTaskGroup.select(
        limit: limit, offset: offset, search: _searchTextController.text);

    _loadedWidgets.addAll(newItems.map((e) => renderRow(e)).toList());
    return newItems.length;
  }

  @override
  Future<void> resetLoader() async {
    await super.resetLoader();
    _loadedWidgets.clear();
    render();
  }

  Widget renderRow(ModelTaskGroup model) {
    return ListTile(
      leading: editButton(model),
      trailing: checkBox(model),
      title: title(model),
      subtitle: subtitle(model),
    );
  }

  Widget title(ModelTaskGroup model) {
    return ListTile(
      title: Text(model.title),
      subtitle: Text(model.description),
    );
  }

  Widget subtitle(ModelTaskGroup model) {
    return Padding(
        padding: const EdgeInsets.only(left: 30),
        child: Text(model.description,
            style:
                TextStyle(fontSize: 12, color: Theme.of(context).hintColor)));
  }

  @override
  Scaffold renderScaffold(Widget body) {
    return AppWidgets.scaffold(context,
        body: body,
        title: 'Groups from Task',
        navBar: AppWidgets.navBarCreateItem(context, name: 'Task Group',
            onCreate: () async {
          var count = (await ModelTaskGroup.count()) + 1;
          var model =
              await ModelTaskGroup.insert(ModelTaskGroup(title: '#$count'));
          if (mounted) {
            await Navigator.pushNamed(context, AppRoutes.editTaskGroup.route,
                arguments: model.id);
            render();
          }
        }));
  }

  Widget checkBox(ModelTaskGroup model) {
    return AppWidgets.checkbox(
      idReference: model.id,
      referenceList: _ids ?? [],
      onToggle: (toggle) async {
        bool add = toggle ?? false;
        if (add) {
          await _model?.addGroup(model);
        } else {
          await _model?.removeGroup(model);
        }
        resetLoader();
      },
    );
  }

  Widget editButton(ModelTaskGroup model) {
    return IconButton(
      icon: const Icon(Icons.edit),
      onPressed: () async {
        await Navigator.pushNamed(context, AppRoutes.editTaskGroup.route,
            arguments: model.id);
        resetLoader();
      },
    );
  }

  @override
  List<Widget> renderBody(BoxConstraints constrains) {
    return _loadedWidgets
        .map((e) => SizedBox(width: constrains.maxWidth, child: e))
        .toList();
  }

  @override
  List<Widget> renderHeader(BoxConstraints constrains) {
    return [
      AppWidgets.searchTile(
          context: context,
          textController: _searchTextController,
          onChange: (String text) {
            resetLoader();
          })
    ];
  }
}
