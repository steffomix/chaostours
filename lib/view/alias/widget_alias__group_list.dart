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
import 'package:chaostours/view/system/app_widgets.dart';
import 'package:chaostours/calendar.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/conf/app_routes.dart';
import 'package:chaostours/model/model_alias_group.dart';
import 'package:chaostours/view/system/app_base_widget.dart';
import 'package:chaostours/util.dart';

typedef CalendarEntry = Map<String?, Calendar>;

class WidgetAliasGroupList extends BaseWidget {
  const WidgetAliasGroupList({super.key});

  @override
  State<WidgetAliasGroupList> createState() => _WidgetAliasGroupList();
}

class _WidgetAliasGroupList extends BaseWidgetState<WidgetAliasGroupList>
    implements BaseWidgetInterface {
  // ignore: unused_field
  static final Logger logger = Logger.logger<WidgetAliasGroupList>();

  final _navBarBuilder = NavBarWithBin();
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
        offset: offset,
        limit: limit,
        search: _searchTextController.text,
        activated: _navBarBuilder.showActivated);

    if (_loadedItems.isNotEmpty) {
      _loadedItems.add(AppWidgets.divider());
    }
    _loadedItems.addAll(
        intersperse(AppWidgets.divider(), newItems.map((e) => renderRow(e))));
    return newItems.length;
  }

  Widget renderRow(ModelAliasGroup model) {
    return Column(children: [
      ListTile(
          title: Text(
            model.title,
            style: _navBarBuilder.showActivated
                ? null
                : const TextStyle(decoration: TextDecoration.lineThrough),
          ),
          subtitle: Text(model.description),
          trailing: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                await Navigator.pushNamed(
                    context, AppRoutes.editAliasGroup.route,
                    arguments: model.id);
                resetLoader();
              })),
      AppWidgets.calendar(_calendars[model.idCalendar]),
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
        navBar: _navBarBuilder.navBar(context,
            name: 'Alias Group',
            onCreate: (context) async {
              final model = await AppWidgets.createAliasGroup(context);
              if (model != null && mounted) {
                await Navigator.pushNamed(
                    context, AppRoutes.editAliasGroup.route,
                    arguments: model.id);
                resetLoader();
              }
            },
            onSwitch: (context) => resetLoader()));
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
