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
import 'package:device_calendar/device_calendar.dart';

///
import 'package:chaostours/view/app_widgets.dart';
import 'package:chaostours/calendar.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/conf/app_routes.dart';
import 'package:chaostours/model/model_alias_group.dart';
import 'package:chaostours/view/app_base_widget.dart';

typedef CalendarEntry = Map<String?, Calendar>;

class WidgetAliasGroupList extends BaseWidget {
  const WidgetAliasGroupList({super.key});

  @override
  State<WidgetAliasGroupList> createState() => _WidgetAliasGroupList();
}

class _WidgetAliasGroupList extends BaseWidgetState<WidgetAliasGroupList>
    implements BaseWidgetPattern {
  // ignore: unused_field
  static final Logger logger = Logger.logger<WidgetAliasGroupList>();

  int _selectedNavBarItem = 0;
  final CalendarEntry _calendars = {};

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
  Future<void> initialize(BuildContext context, Object? args) async {
    try {
      var cals = (await AppCalendar().loadCalendars());
      for (var c in cals) {
        _calendars.addEntries({c.id: c}.entries);
      }
    } catch (e) {
      logger.warn('maybe no calendar permission granted: $e');
    }
  }

  @override
  Future<int> loadItems({required int offset, int limit = 20}) async {
    List<ModelAliasGroup> newItems = await ModelAliasGroup.select(
        offset: offset, limit: limit, search: _searchTextController.text);

    _loadedItems.addAll(newItems.map((e) => renderItem(e)).toList());
    return newItems.length;
  }

  Widget renderItem(ModelAliasGroup model) {
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
      AppWidgets.calendar(_calendars[model.idCalendar]),
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
                    var count = await ModelAliasGroup.count();
                    var model = await ModelAliasGroup.insert(
                        ModelAliasGroup(title: '#${count + 1}'));
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
