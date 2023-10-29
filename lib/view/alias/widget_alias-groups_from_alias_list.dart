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
import 'package:chaostours/model/model_alias_group.dart';
import 'package:chaostours/model/model_alias.dart';

class WidgetAliasGroupsFromAliasList extends BaseWidget {
  const WidgetAliasGroupsFromAliasList({super.key});

  @override
  State<WidgetAliasGroupsFromAliasList> createState() =>
      _WidgetAliasGroupsFromAliasList();
}

class _WidgetAliasGroupsFromAliasList
    extends BaseWidgetState<WidgetAliasGroupsFromAliasList> {
  // ignore: unused_field
  static final Logger logger = Logger.logger<WidgetAliasGroupsFromAliasList>();

  int _selectedNavBarItem = 0;

  final TextEditingController _searchTextController = TextEditingController();
  final List<Widget> _loadedWidgets = [];
  ModelAlias? _model;
  List<int>? _ids;
  // items per page
  int getLimit() => 30;

  @override
  Future<void> initialize(BuildContext context, Object? args) async {
    _model = await ModelAlias.byId(args as int);
    _ids ??= await _model?.groupIds() ?? [];
  }

  @override
  Future<int> loadItems({required int offset, int limit = 20}) async {
    var newItems = await ModelAliasGroup.select(
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

  Widget renderRow(ModelAliasGroup model) {
    return ListTile(
      leading: editButton(model),
      trailing: checkBox(model),
      title: title(model),
      subtitle: subtitle(model),
    );
  }

  Widget title(ModelAliasGroup model) {
    return ListTile(
      title: Text(model.title),
      subtitle: Text(model.description),
    );
  }

  Widget subtitle(ModelAliasGroup model) {
    return Padding(
        padding: const EdgeInsets.only(left: 30),
        child: Text(model.description,
            style:
                TextStyle(fontSize: 12, color: Theme.of(context).hintColor)));
  }

  @override
  Scaffold renderScaffold(Widget body) {
    return AppWidgets.scaffold(context, body: body, title: 'Groups from Alias');
  }

  Widget checkBox(ModelAliasGroup model) {
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

  Widget editButton(ModelAliasGroup model) {
    return IconButton(
      icon: const Icon(Icons.edit),
      onPressed: () {
        Navigator.pushNamed(context, AppRoutes.aliasGroupEdit.route,
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
      AppWidgets.searchTile(
          context: context,
          textController: _searchTextController,
          onChange: (String text) {
            resetLoader();
          })
    ];
  }

  BottomNavigationBar navBar(BuildContext context) {
    return BottomNavigationBar(
        currentIndex: _selectedNavBarItem,
        items: const [
          // new on osm
          BottomNavigationBarItem(
              icon: Icon(Icons.add), label: 'Create new Group'),
          // 2 nearest
          BottomNavigationBarItem(icon: Icon(Icons.near_me), label: 'Back'),
        ],
        onTap: (int id) async {
          _selectedNavBarItem = id;

          switch (id) {
            /// create
            case 0:
              var count = await ModelAliasGroup.count();
              var model = ModelAliasGroup(title: '#${count + 1}');
              model = await ModelAliasGroup.insert(model);
              if (mounted) {
                Navigator.pushNamed(context, AppRoutes.aliasGroupEdit.route,
                        arguments: model.id)
                    .then((_) {
                  resetLoader();
                });
              }

              break;

            /// last visited
            case 1:
              if (mounted) {
                Navigator.pop(context);
              }
              break;

            /// default view
            default:
              setState(() {});
            //
          }
        });
  }
}
