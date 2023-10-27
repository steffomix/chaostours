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
import 'package:chaostours/conf/app_colors.dart';
import 'package:chaostours/model/model_alias.dart';
import 'package:chaostours/view/app_base_widget.dart';
import 'package:chaostours/gps.dart';

enum _DisplayMode {
  list,
  search,
  nearest;
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

  int _selectedNavBarItem = 0;

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
  Future<int> load({required int offset, int limit = 20}) async {
    List<ModelAlias> newItems = [];
    switch (_displayMode) {
      case _DisplayMode.list:
        newItems.addAll(await ModelAlias.select(offset: offset, limit: limit));
        break;

      case _DisplayMode.search:
        newItems.addAll(await ModelAlias.search(_searchTextController.text,
            offset: offset, limit: limit));
        break;

      case _DisplayMode.nearest:
        newItems.addAll(await ModelAlias.nextAlias(
            gps: _gps ??= (await GPS.gps()), area: 10000));
        break;

      default:
        return 0;
    }
    _loadedItems.addAll(newItems.map((e) => renderItem(e)).toList());
    return newItems.length;
  }

  Widget itemTitle(ModelAlias model) {
    int dur = DateTime.now().difference(model.lastVisited).inDays;
    int count = model.trackPointCount;
    return ListTile(
        subtitle: Text(
            '#${model.sortDistance} Besucht: ${count}x, ${count == 0 ? 'noch nie' : 'vor $dur Tage'}'),
        title: Text(model.title));
  }

  Widget itemSubtitle(ModelAlias model) {
    return Padding(
        padding: const EdgeInsets.only(left: 30),
        child: Text(model.description,
            style:
                TextStyle(fontSize: 12, color: Theme.of(context).hintColor)));
  }

  Widget itemInfo(ModelAlias model) {
    return IconButton(
      icon: Icon(Icons.info_outline_rounded,
          size: 30,
          color: model.isActive
              ? Colors.black
              : AppColors.aliasStatusColor(model.visibility)),
      onPressed: () {
        Navigator.pushNamed(context, AppRoutes.listAliasTrackpoints.route,
                arguments: model.id)
            .then((_) {
          setState(() {});
        });
      },
    );
  }

  Widget renderItem(ModelAlias model) {
    return model.description.isEmpty
        ? ListTile(trailing: itemInfo(model), title: itemTitle(model))
        : ListTile(
            trailing: itemInfo(model),
            title: itemTitle(model),
            subtitle: itemSubtitle(model),
          );
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
      ListTile(
          trailing: IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              _searchTextController.text = "";
              _displayMode = _DisplayMode.list;
              _selectedNavBarItem = 2; // last visited
              resetLoader();
            },
          ),
          title: TextField(
            controller: _searchTextController,
            minLines: 1,
            maxLines: 1,
            decoration: const InputDecoration(
              isDense: true,
              //con: Icon(Icons.search, size: 30),
              border: OutlineInputBorder(),
              labelText: "Search",
              contentPadding: EdgeInsets.all(10),
            ),
            onChanged: (value) {
              _displayMode =
                  value.isEmpty ? _DisplayMode.list : _DisplayMode.search;
              _selectedNavBarItem = 2; // last visited
              resetLoader();
            },
          ))
    ];
  }

  BottomNavigationBar navBar(BuildContext context) {
    return BottomNavigationBar(
        currentIndex: _selectedNavBarItem,
        items: const [
          // new on osm
          BottomNavigationBarItem(
              icon: Icon(Icons.add), label: 'Create new Alias'),
          // 2 nearest
          BottomNavigationBarItem(
              icon: Icon(Icons.near_me), label: 'Nearby Aliases'),
          // 1 alphabethic
          BottomNavigationBarItem(
              icon: Icon(Icons.timer), label: 'Last visited'),
        ],
        onTap: (int id) {
          _selectedNavBarItem = id;
          switch (id) {
            /// create
            case 0:
              Navigator.pushNamed(context, AppRoutes.osm.route).then((_) {
                resetLoader();
              });

              break;

            /// last visited
            case 1:
              GPS.gps().then((GPS gps) {
                _gps = gps;
                _displayMode = _DisplayMode.nearest;
                resetLoader();
              });
              break;

            case 2:
              _displayMode = _DisplayMode.list;
              resetLoader();
              break;

            /// default view
            default:
              setState(() {});
            //
          }
        });
  }
}
