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

import 'package:chaostours/view/system/app_base_widget.dart';
import 'package:chaostours/view/system/app_widgets.dart';
import 'package:flutter/material.dart';

///
import 'package:chaostours/logger.dart';
import 'package:chaostours/conf/app_routes.dart';
import 'package:chaostours/model/model_task.dart';
import 'package:chaostours/util.dart';

class WidgetTaskList extends BaseWidget {
  const WidgetTaskList({super.key});

  @override
  State<WidgetTaskList> createState() => _WidgetTaskList();
}

class _WidgetTaskList extends BaseWidgetState<WidgetTaskList> {
  // ignore: unused_field
  static final Logger logger = Logger.logger<WidgetTaskList>();

  final _navBarBuilder = NavBarWithBin();
  final _textController = TextEditingController();

  final List<Widget> _loadedItems = [];

  @override
  Future<void> initialize(BuildContext context, Object? args) async {}

  @override
  Future<void> resetLoader() async {
    await super.resetLoader();
    _loadedItems.clear();
    render();
  }

  @override
  Future<int> loadItems({required int offset, int limit = 20}) async {
    List<ModelTask> newItems = await ModelTask.select(
        limit: limit,
        offset: offset,
        activated: _navBarBuilder.showActivated,
        search: _textController.text);

    if (_loadedItems.isNotEmpty) {
      _loadedItems.add(AppWidgets.divider());
    }
    _loadedItems.addAll(
        intersperse(AppWidgets.divider(), newItems.map((e) => renderRow(e))));
    return newItems.length;
  }

  @override
  List<Widget> renderBody(BoxConstraints constraints) {
    return _loadedItems
        .map((e) => SizedBox(width: constraints.maxWidth, child: e))
        .toList();
  }

  @override
  List<Widget> renderHeader(BoxConstraints constraints) {
    return [
      AppWidgets.searchTile(
          context: context,
          textController: _textController,
          onChange: (search) {
            resetLoader();
          })
    ];
  }

  @override
  Scaffold renderScaffold(Widget body) {
    return AppWidgets.scaffold(context,
        body: body, title: 'Tasks', navBar: navBar());
  }

  BottomNavigationBar navBar() {
    return _navBarBuilder.navBar(context,
        name: 'Task',
        onCreate: (context) async {
          final newTask = await AppWidgets.createTask(context);
          if (newTask != null && mounted) {
            Navigator.pushNamed(context, AppRoutes.editTask.route,
                    arguments: newTask.id)
                .then((value) {
              Navigator.pop(context);
              resetLoader();
            });
          }
        },
        onSwitch: (context) => resetLoader());
  }

  Widget renderRow(ModelTask model) {
    return ListTile(
        title: Text(model.title,
            style: TextStyle(
                decoration: model.isActive
                    ? TextDecoration.none
                    : TextDecoration.lineThrough)),
        subtitle: Text(
          model.description,
          style: TextStyle(color: Theme.of(context).hintColor),
        ),
        trailing: IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              await Navigator.pushNamed(context, AppRoutes.editTask.route,
                  arguments: model.id);
              resetLoader();
            }));
  }
}
