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
import 'package:chaostours/logger.dart';
import 'package:chaostours/calendar.dart';
import 'package:chaostours/conf/app_routes.dart';
import 'package:chaostours/view/system/app_widgets.dart';
import 'package:chaostours/view/system/app_base_widget.dart';
import 'package:chaostours/model/model_location_group.dart';
import 'package:chaostours/model/model_location.dart';
import 'package:chaostours/util.dart';

typedef CalendarEntry = Map<String?, Calendar>;

class WidgetLocationsFromLocationGroupList extends BaseWidget {
  const WidgetLocationsFromLocationGroupList({super.key});
  @override
  State<WidgetLocationsFromLocationGroupList> createState() =>
      _WidgetLocationsFromLocationGroupList();
}

class _WidgetLocationsFromLocationGroupList
    extends BaseWidgetState<WidgetLocationsFromLocationGroupList>
    implements BaseWidgetInterface {
  static final Logger logger =
      Logger.logger<WidgetLocationsFromLocationGroupList>();

  final CalendarEntry _calendars = {};
  final _navBarBuilder = NavBarWithBin();

  final TextEditingController _searchTextController = TextEditingController();
  final List<Widget> _loadedWidgets = [];
  ModelLocationGroup? _model;
  List<int>? _ids;
  // items per page
  int getLimit() => 30;

  @override
  Future<void> initialize(BuildContext context, Object? args) async {
    _model = await ModelLocationGroup.byId(args as int);
    _ids ??= await _model?.locationIds() ?? [];
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
    var newItems = await ModelLocation.select(
        limit: limit,
        offset: offset,
        search: _searchTextController.text,
        activated: _navBarBuilder.showActivated);

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

  Widget renderRow(ModelLocation model) {
    return ListTile(
      leading: IconButton(
        icon: const Icon(Icons.edit),
        onPressed: () {
          Navigator.pushNamed(context, AppRoutes.editLocation.route,
                  arguments: model.id)
              .then(
            (value) {
              resetLoader();
            },
          );
        },
      ),
      trailing: AppWidgets.multiCheckbox(
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
            resetLoader();
          } catch (e, stk) {
            logger.error('checkbox _model is NULL; $e', stk);
          }
        },
      ),
      title: Text(model.title,
          style: _navBarBuilder.showActivated
              ? null
              : const TextStyle(decoration: TextDecoration.lineThrough)),
      subtitle: Text(model.description),
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
        subtitle: Text(cutString(_model?.description ?? ''),
            style: TextStyle(color: Theme.of(context).hintColor)),
      ),
      AppWidgets.calendar(_calendars[_model?.idCalendar]),
      AppWidgets.searchTile(
          context: context,
          textController: _searchTextController,
          onChange: (String text) {
            resetLoader();
          }),
      AppWidgets.divider()
    ];
  }

  @override
  Scaffold renderScaffold(Widget body) {
    return AppWidgets.scaffold(context,
        body: body,
        title: 'Locations from group',
        navBar: _navBarBuilder.navBar(context,
            name: 'Location',
            onCreate: (context) async {
              await Navigator.pushNamed(context, AppRoutes.osm.route);
              resetLoader();
            },
            onSwitch: (context) => resetLoader()));
  }
}
