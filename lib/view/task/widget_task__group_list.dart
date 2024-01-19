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
import 'package:chaostours/view/system/app_widgets.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/conf/app_routes.dart';
import 'package:chaostours/model/model_task_group.dart';
import 'package:chaostours/view/system/app_base_widget.dart';
import 'package:chaostours/util.dart';

class WidgetTaskGroupList extends BaseWidget {
  const WidgetTaskGroupList({super.key});

  @override
  State<WidgetTaskGroupList> createState() => _WidgetTaskGroupList();
}

class _WidgetTaskGroupList extends BaseWidgetState<WidgetTaskGroupList>
    implements BaseWidgetInterface {
  // ignore: unused_field
  static final Logger logger = Logger.logger<WidgetTaskGroupList>();

  List<Widget> _loadedItems = [];

  final TextEditingController _searchTextController = TextEditingController();

  // items per page
  @override
  int loaderLimit() => 20;

  @override
  Future<void> resetLoader() async {
    await super.resetLoader();
    _loadedItems = [];
    render();
  }

  @override
  Future<int> loadItems({required int offset, int limit = 20}) async {
    List<ModelTaskGroup> newItems = await ModelTaskGroup.select(
        offset: offset, limit: limit, search: _searchTextController.text);

    if (_loadedItems.isNotEmpty) {
      _loadedItems.add(AppWidgets.divider());
    }
    _loadedItems.addAll(
        intersperse(AppWidgets.divider(), newItems.map((e) => renderRow(e))));
    return newItems.length;
  }

  Widget renderRow(ModelTaskGroup model) {
    return Column(children: [
      ListTile(
          title: Text(model.title),
          subtitle: Text(model.description),
          trailing: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.editTaskGroup.route,
                        arguments: model.id)
                    .then(
                  (value) => resetLoader(),
                );
              })),
      settings(model),
    ]);
  }

  Widget settings(ModelTaskGroup model) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
      Text(
        'selectable',
        style: model.isSelectable
            ? null
            : TextStyle(
                decoration: TextDecoration.lineThrough,
                color: Theme.of(context).disabledColor,
                decorationColor: Theme.of(context).disabledColor),
      ),
      Text(
        'preselected',
        style: model.isPreselected
            ? null
            : TextStyle(
                decoration: TextDecoration.lineThrough,
                color: Theme.of(context).disabledColor,
                decorationColor: Theme.of(context).disabledColor),
      )
    ]);
  }

  @override
  List<Widget> renderBody(BoxConstraints constraints) {
    return _loadedItems
        .map((e) => SizedBox(width: constraints.maxWidth, child: e))
        .toList();
  }

  @override
  Scaffold renderScaffold(Widget body) {
    return AppWidgets.scaffold(context,
        body: body,
        navBar: AppWidgets.navBarCreateItem(context, name: 'Task Group',
            onCreate: () async {
          final model = await AppWidgets.createTaskGroup(context);
          if (model != null && mounted) {
            await Navigator.pushNamed(context, AppRoutes.editTaskGroup.route,
                arguments: model.id);
            resetLoader();
          }
        }));
  }

  @override
  List<Widget> renderHeader(BoxConstraints constraints) {
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
