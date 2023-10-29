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
import 'package:chaostours/model/model_alias.dart';
import 'package:chaostours/view/app_base_widget.dart';
import 'package:chaostours/gps.dart';

enum _DisplayMode {
  list,
  nearest,
}

class WidgetAliasList extends BaseWidget {
  const WidgetAliasList({super.key});

  @override
  State<WidgetAliasList> createState() => _WidgetAliasList();
}

class _WidgetAliasList extends BaseWidgetState<WidgetAliasList>
    implements BaseWidgetPattern {
  // ignore: unused_field
  static final Logger logger = Logger.logger<WidgetAliasList>();

  _DisplayMode _displayMode = _DisplayMode.list;

  int _selectedNavBarItem = 1;

  bool _showActivated = true;
  bool _lastVisited = false;

  List<Widget> _loadedItems = [];

  GPS? _gps;

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
    List<ModelAlias> newItems = [];
    if (_displayMode == _DisplayMode.nearest) {
      newItems.addAll(await ModelAlias.nextAlias(
          gps: _gps ??= (await GPS.gps()), area: 10000));
    } else {
      newItems.addAll(await ModelAlias.select(
          offset: offset,
          limit: limit,
          activated: _showActivated,
          lastVisited: _lastVisited,
          search: _searchTextController.text));
    }
    _loadedItems.addAll(newItems.map((e) => renderItem(e)).toList());
    return newItems.length;
  }

  Widget itemTitle(ModelAlias model) {
    int dur = DateTime.now().difference(model.lastVisited).inDays;
    int count = model.trackPointCount;
    return ListTile(
        subtitle: Text(
            style: model.isActive
                ? null
                : const TextStyle(decoration: TextDecoration.lineThrough),
            'Visited: ${count}x, ${count == 0 ? 'Never' : 'before $dur days.'}'),
        title: Text(model.title));
  }

  Widget itemSubtitle(ModelAlias model) {
    return Padding(
        padding: const EdgeInsets.only(left: 30),
        child: Text(model.description,
            style:
                TextStyle(fontSize: 12, color: Theme.of(context).hintColor)));
  }

  Widget showTrackpoints(ModelAlias model) {
    return IconButton(
      icon: const Icon(Icons.list),
      onPressed: () {
        Navigator.pushNamed(context, AppRoutes.trackpointsFromAliasList.route,
                arguments: model.id)
            .then((_) {
          render();
        });
      },
    );
  }

  Widget edit(ModelAlias model) {
    return IconButton(
      icon: const Icon(Icons.edit),
      onPressed: () {
        Navigator.pushNamed(context, AppRoutes.editAlias.route,
                arguments: model.id)
            .then((_) {
          resetLoader();
        });
      },
    );
  }

  Widget renderItem(ModelAlias model) {
    return ListTile(
        leading: showTrackpoints(model),
        title: itemTitle(model),
        subtitle: itemSubtitle(model),
        trailing: edit(model));
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
        body: body, navBar: navBar(context), title: 'Aliases');
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
        items: [
          // 0
          const BottomNavigationBarItem(
              icon: Icon(Icons.add), label: 'Create new Alias'),
          // 1
          _lastVisited
              ? const BottomNavigationBarItem(
                  icon: Icon(Icons.timer), label: 'Last visited')
              : const BottomNavigationBarItem(
                  icon: Icon(Icons.list), label: 'List'),
          // 2
          const BottomNavigationBarItem(
              icon: Icon(Icons.near_me), label: 'Nearest'),
          // 3
          _showActivated
              ? const BottomNavigationBarItem(
                  icon: Icon(Icons.delete), label: 'Show Deactivated')
              : const BottomNavigationBarItem(
                  icon: Icon(Icons.visibility), label: 'Show Active'),
          // 2
          const BottomNavigationBarItem(
              icon: Icon(Icons.cancel), label: 'Cancel'),
        ],
        onTap: (int id) {
          _selectedNavBarItem = id;
          switch (id) {
            /// create
            case 0:
              _displayMode = _DisplayMode.list;
              _showActivated = true;
              Navigator.pushNamed(context, AppRoutes.osm.route).then((_) {
                resetLoader();
                _selectedNavBarItem = 1;
              });

              break;

            /// list / last visited
            case 1:
              _displayMode = _DisplayMode.list;
              _showActivated = true;
              _lastVisited = !_lastVisited;
              _selectedNavBarItem = 1;
              resetLoader();
              break;

            /// nearby
            case 2:
              GPS.gps().then((GPS gps) {
                _gps = gps;
                _showActivated = true;
                _displayMode = _DisplayMode.nearest;
                _selectedNavBarItem = 2;
                resetLoader();
              });
              break;

            /// trash
            case 3:
              _showActivated = !_showActivated;
              _displayMode = _DisplayMode.list;
              _selectedNavBarItem = 3;
              resetLoader();
              break;

            /// return
            case 4:
              Navigator.pop(context);

            default:
              _displayMode = _DisplayMode.list;
              setState(() {});
            //
          }
        });
  }
}
