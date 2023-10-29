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
import 'package:chaostours/logger.dart';
import 'package:chaostours/conf/app_routes.dart';
import 'package:chaostours/model/model_task_group.dart';
import 'package:chaostours/view/app_base_widget.dart';

class WidgetTaskGroupList extends BaseWidget {
  const WidgetTaskGroupList({super.key});

  @override
  State<WidgetTaskGroupList> createState() => _WidgetTaskGroupList();
}

class _WidgetTaskGroupList extends BaseWidgetState<WidgetTaskGroupList>
    implements BaseWidgetPattern {
  // ignore: unused_field
  static final Logger logger = Logger.logger<WidgetTaskGroupList>();

  int _selectedNavBarItem = 0;

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

    _loadedItems.addAll(newItems.map((e) => renderItem(e)).toList());
    return newItems.length;
  }

  Widget renderItem(ModelTaskGroup model) {
    return Column(children: [
      ListTile(
          title: Text(model.title),
          subtitle: Text(model.description),
          trailing: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.aliasGroupEdit.route,
                        arguments: model.id)
                    .then(
                  (value) => resetLoader(),
                );
              })),
      AppWidgets.divider()
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
    return AppWidgets.scaffold(context, body: body, navBar: navBar(context));
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

  BottomNavigationBar navBar(BuildContext context) {
    return BottomNavigationBar(
        currentIndex: _selectedNavBarItem,
        items: const [
          // new on osm
          BottomNavigationBarItem(
              icon: Icon(Icons.add), label: 'Create new Group'),
          // 1 alphabethic
          BottomNavigationBarItem(icon: Icon(Icons.cancel), label: 'Cancel'),
        ],
        onTap: (int id) {
          _selectedNavBarItem = id;
          switch (id) {
            /// create
            case 0:
              AppWidgets.dialog(context: context, contents: [
                const Text('Create new Group?')
              ], buttons: [
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.pop(context),
                ),
                TextButton(
                  child: const Text('Yes'),
                  onPressed: () async {
                    var count = await ModelTaskGroup.count();
                    var model = await ModelTaskGroup.insert(
                        ModelTaskGroup(title: '#${count + 1}'));
                    if (mounted) {
                      Navigator.pushNamed(
                              context, AppRoutes.aliasGroupEdit.route,
                              arguments: model.id)
                          .then((value) {
                        Navigator.pop(context);
                        resetLoader();
                      });
                    }
                  },
                )
              ]);
              break;
            // return
            case 1:
              Navigator.pop(context);
              break;

            default:
              resetLoader();
          }
        });
  }
}
