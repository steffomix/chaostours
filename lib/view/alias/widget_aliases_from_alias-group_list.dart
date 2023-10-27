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
// import 'package:chaostours/logger.dart';
import 'package:chaostours/view/app_widgets.dart';
import 'package:chaostours/view/app_base_widget.dart';
import 'package:chaostours/model/model_alias_group.dart';
import 'package:chaostours/model/model_alias.dart';
import 'package:chaostours/util.dart';

class WidgetAliasesFromAliasGroupList extends BaseWidget {
  const WidgetAliasesFromAliasGroupList({Key? key}) : super(key: key);
  @override
  State<WidgetAliasesFromAliasGroupList> createState() =>
      _WidgetAliasGroupAliasList();
}

class _WidgetAliasGroupAliasList
    extends BaseWidgetState<WidgetAliasesFromAliasGroupList>
    implements BaseWidgetPattern {
  //static final Logger logger = Logger.logger<WidgetAliasGroupAliasList>();

  final List<Widget> loadedItems = [];
  final _searchController = TextEditingController();

  @override
  int loaderLimit() => 20;

  ModelAliasGroup? _model;

  @override
  Future<void> initialize(BuildContext context, Object? args) async {
    _model = await ModelAliasGroup.byId(args as int);
  }

  @override
  Future<void> resetLoader() async {
    await super.resetLoader();
    loadedItems.clear();
    render();
  }

  @override
  Future<int> loadItems({required int offset, int limit = 20}) async {
    var rows = await _model?.children(
        offset: offset, limit: limit, search: _searchController.text);
    if (rows != null) {
      loadedItems.addAll(rows.map((e) => renderRow(e)));
    }
    return rows?.length ?? 0;
  }

  @override
  List<Widget> renderHeader(BoxConstraints constraints) {
    return <Widget>[
      ListTile(
        title: Text(_model?.title ?? 'no Model'),
        subtitle: Text(_model?.description ?? ''),
      ),
      AppWidgets.searchTile(
          context: context,
          textController: _searchController,
          onChange: (String text) {
            resetLoader();
          }),
      AppWidgets.divider()
    ];
  }

  @override
  List<Widget> renderBody(BoxConstraints constraints) {
    return loadedItems
        .map(
          (e) => SizedBox(width: constraints.maxWidth, child: e),
        )
        .toList();
  }

  Widget renderRow(ModelAlias model) {
    return AppWidgets.checkboxListTile(CheckboxController(
      idReference: model.id,
      referenceList: [model.id],
      checked: true,
      title: model.title,
      subtitle: model.description,
      onToggle: (toggle) async {
        AppWidgets.dialog(context: context, contents: const [
          Text(
              'Warning!\nOn this Page you can only remove Items from this group. To add this Item again, you will need to find it on the alias list.')
        ], buttons: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text('Remove anyway'),
            onPressed: () async {
              Navigator.pop(context);
              await model.removeGroup(_model!);
              resetLoader();
            },
          )
        ]);
      },
    ));
  }

  @override
  Scaffold renderScaffold(Widget body) {
    return AppWidgets.scaffold(
      context,
      appBar: AppBar(
        title: const Text('Aliases from:'),
      ),
      body: body,
    );
  }
}
