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
import 'package:chaostours/view/system/app_widgets.dart';
import 'package:chaostours/view/system/app_base_widget.dart';
import 'package:chaostours/model/model_user_group.dart';
import 'package:chaostours/model/model_user.dart';
import 'package:chaostours/util.dart';

class WidgetUsersFromUserGroupList extends BaseWidget {
  const WidgetUsersFromUserGroupList({super.key});

  @override
  State<WidgetUsersFromUserGroupList> createState() =>
      _WidgetUsersFromUserGroupList();
}

class _WidgetUsersFromUserGroupList
    extends BaseWidgetState<WidgetUsersFromUserGroupList> {
  // ignore: unused_field
  static final Logger logger = Logger.logger<WidgetUsersFromUserGroupList>();

  final TextEditingController _searchTextController = TextEditingController();
  final List<Widget> _loadedWidgets = [];
  ModelUserGroup? _model;
  List<int>? _ids;
  // items per page
  int getLimit() => 30;

  @override
  Future<void> initialize(BuildContext context, Object? args) async {
    _model = await ModelUserGroup.byId(args as int);
    _ids ??= await _model?.userIds();
  }

  @override
  Future<int> loadItems({required int offset, int limit = 20}) async {
    var newItems = await ModelUser.select(
        limit: limit, offset: offset, search: _searchTextController.text);

    if (_loadedWidgets.isNotEmpty) {
      _loadedWidgets.add(AppWidgets.divider());
    }
    _loadedWidgets.addAll(
        intersperse(AppWidgets.divider(), newItems.map((e) => renderRow(e))));
    return newItems.length;
  }

  @override
  Future<void> resetLoader() async {
    await super.resetLoader();
    _loadedWidgets.clear();
    render();
  }

  Widget renderRow(ModelUser model) {
    return ListTile(
      leading: editButton(model),
      trailing: checkBox(model),
      title: title(model),
      subtitle: subtitle(model),
    );
  }

  Widget title(ModelUser model) {
    return ListTile(
      title: Text(model.title),
      subtitle: Text(model.description),
    );
  }

  Widget subtitle(ModelUser model) {
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
        title: 'Users from Group',
        navBar: AppWidgets.navBarCreateItem(context, name: 'User',
            onCreate: () async {
          final model = await AppWidgets.createUser(context);
          if (model != null && mounted) {
            await Navigator.pushNamed(context, AppRoutes.editUser.route,
                arguments: model.id);
            resetLoader();
          }
        }));
  }

  Widget checkBox(ModelUser model) {
    return AppWidgets.multiCheckbox(
      id: model.id,
      idList: _ids ?? [],
      onToggle: (toggle) async {
        bool add = toggle ?? false;
        try {
          if (add) {
            await model.addGroup(_model!);
          } else {
            await model.removeGroup(_model!);
          }
        } catch (e, stk) {
          logger.error('toggle checkbox: $e', stk);
        }
      },
    );
  }

  Widget editButton(ModelUser model) {
    return IconButton(
      icon: const Icon(Icons.edit),
      onPressed: () {
        Navigator.pushNamed(context, AppRoutes.editUser.route,
                arguments: model.id)
            .then(
          (value) {
            resetLoader();
          },
        );
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
      ListTile(
        title: Text(cutString(_model?.title ?? '')),
        subtitle: Text(cutString(_model?.description ?? '')),
      ),
      AppWidgets.searchTile(
          context: context,
          textController: _searchTextController,
          onChange: (String text) {
            resetLoader();
          }),
      AppWidgets.divider()
    ];
  }
}
