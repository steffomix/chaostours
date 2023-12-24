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

import 'package:chaostours/view/app_base_widget.dart';
import 'package:flutter/material.dart';

///
import 'package:chaostours/logger.dart';
import 'package:chaostours/conf/app_routes.dart';
import 'package:chaostours/view/app_widgets.dart';
import 'package:chaostours/model/model_user_group.dart';

class WidgetUserGroupList extends BaseWidget {
  const WidgetUserGroupList({super.key});

  @override
  State<WidgetUserGroupList> createState() => _WidgetUserGroupList();
}

class _WidgetUserGroupList extends BaseWidgetState<WidgetUserGroupList> {
  // ignore: unused_field
  static final Logger logger = Logger.logger<WidgetUserGroupList>();

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
    List<ModelUserGroup> newItems = await ModelUserGroup.select(
        offset: offset, limit: limit, search: _searchTextController.text);

    _loadedItems.addAll(newItems.map((e) => renderItem(e)).toList());
    return newItems.length;
  }

  Widget renderItem(ModelUserGroup model) {
    return Column(children: [
      ListTile(
          title: Text(model.title),
          subtitle: Text(model.description),
          trailing: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.editUserGroup.route,
                        arguments: model.id)
                    .then(
                  (value) => resetLoader(),
                );
              })),
      settings(model),
      AppWidgets.divider()
    ]);
  }

  Widget settings(ModelUserGroup model) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
      Text(
        'selectable',
        style: model.isSelectable
            ? null
            : const TextStyle(decoration: TextDecoration.lineThrough),
      ),
      Text(
        'preselected',
        style: model.isPreselected
            ? null
            : const TextStyle(decoration: TextDecoration.lineThrough),
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
