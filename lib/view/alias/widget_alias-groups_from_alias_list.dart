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

  final TextEditingController _searchTextController = TextEditingController();
  final List<Widget> _loadedWidgets = [];
  final _navBarBuilder = NavBarWithTrash();
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
        limit: limit,
        offset: offset,
        search: _searchTextController.text,
        activated: _navBarBuilder.showActivated);

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
      leading: IconButton(
        icon: const Icon(Icons.edit),
        onPressed: () {
          Navigator.pushNamed(context, AppRoutes.editAliasGroup.route,
                  arguments: model.id)
              .then(
            (value) {
              resetLoader();
            },
          );
        },
      ),
      trailing: AppWidgets.checkbox(
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
      ),
      title: Text(
        model.title,
        style: _navBarBuilder.showActivated
            ? null
            : const TextStyle(decoration: TextDecoration.lineThrough),
      ),
      subtitle: Text(model.description,
          style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
    );
  }

  @override
  Scaffold renderScaffold(Widget body) {
    return AppWidgets.scaffold(context,
        body: body,
        title: 'Groups from Alias',
        navBar: _navBarBuilder.navBar(context,
            name: 'Alias Group',
            onCreate: (context) async {
              var count = await ModelAliasGroup.count();
              var model = await ModelAliasGroup.insert(
                  ModelAliasGroup(title: '#${count + 1}'));
              if (mounted) {
                Navigator.pushNamed(context, AppRoutes.editAliasGroup.route,
                        arguments: model.id)
                    .then((value) {
                  Navigator.pop(context);
                  resetLoader();
                });
              }
            },
            onSwitch: (context) => resetLoader()));
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
        title: Text(_model?.title ?? ''),
        subtitle: Text(_model?.description ?? '',
            style: TextStyle(color: Theme.of(context).hintColor)),
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
