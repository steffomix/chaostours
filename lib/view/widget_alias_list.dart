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
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

///
import 'package:chaostours/screen.dart';
import 'package:chaostours/view/app_widgets.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/conf/app_routes.dart';
import 'package:chaostours/conf/app_colors.dart';
import 'package:chaostours/model/model_alias.dart';
import 'package:chaostours/gps.dart';

enum _DisplayMode {
  list,
  search,
  nearest;
}

class WidgetAliasList extends StatefulWidget {
  const WidgetAliasList({super.key});

  @override
  State<WidgetAliasList> createState() => _WidgetAliasList();
}

class _WidgetAliasList extends State<WidgetAliasList> {
  // ignore: unused_field
  static final Logger logger = Logger.logger<WidgetAliasList>();

  _DisplayMode _displayMode = _DisplayMode.list;

  int _selectedNavBarItem = 0;

  GPS? _gps;

  // height of seasrch field container
  final double _toolBarHeight = 70;

  final TextEditingController _searchTextController = TextEditingController();

  // items per page
  static const int _limit = 30;

  final PagingController<int, ModelAlias> _pagingController =
      PagingController(firstPageKey: 0);

  Future<void> _fetchPage(int offset) async {
    try {
      List<ModelAlias> newItems = [];
      switch (_displayMode) {
        case _DisplayMode.list:
          newItems
              .addAll(await ModelAlias.select(offset: offset, limit: _limit));
          break;

        case _DisplayMode.search:
          newItems.addAll(await ModelAlias.search(_searchTextController.text,
              offset: offset, limit: _limit));
          break;

        case _DisplayMode.nearest:
          newItems.addAll(await ModelAlias.nextAlias(gps: _gps!, area: 10000));
          break;

        default:
        //
      }
      final isLastPage =
          newItems.length < _limit || _displayMode == _DisplayMode.nearest;
      if (isLastPage) {
        _pagingController.appendLastPage(newItems);
      } else {
        _pagingController.appendPage(newItems, offset + newItems.length);
      }
    } catch (error) {
      _pagingController.error = error;
    }
  }

  @override
  void dispose() {
    _pagingController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    _pagingController.addPageRequestListener(_fetchPage);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    var body = CustomScrollView(
      slivers: <Widget>[
        /// Pinned header
        SliverPersistentHeader(
            pinned: true,
            delegate: SliverHeader(
                widget: searchWidget(), //Text('Test'),
                toolBarHeight: _toolBarHeight,
                closedHeight: 0,
                openHeight: 0)),

        /// Items List
        PagedSliverList<int, ModelAlias>.separated(
          separatorBuilder: (BuildContext context, int i) => const Divider(),
          pagingController: _pagingController,
          builderDelegate: PagedChildBuilderDelegate<ModelAlias>(
            itemBuilder: (context, model, index) => model.description.isEmpty
                ? ListTile(trailing: btnInfo(model), title: title(model))
                : ListTile(
                    trailing: btnInfo(model),
                    title: title(model),
                    subtitle: subtitle(model),
                  ),
          ),
        ),
      ],
    );
    return AppWidgets.scaffold(context,
        body: body,
        navBar: navBar(context),
        appBar: AppBar(title: const Text('Alias List')));
  }

  Widget title(ModelAlias model) {
    int dur = DateTime.now().difference(model.lastVisited).inDays;
    int count = model.trackPointCount;
    return ListTile(
        subtitle: Text(
            '#${model.sortDistance} Besucht: ${count}x, ${count == 0 ? 'noch nie' : 'vor $dur Tage'}'),
        title: Text(model.title));
  }

  Widget subtitle(ModelAlias model) {
    return Padding(
        padding: const EdgeInsets.only(left: 30),
        child: Text(model.description,
            style:
                TextStyle(fontSize: 12, color: Theme.of(context).hintColor)));
  }

  Widget btnInfo(ModelAlias model) {
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

  Widget searchWidget() {
    return SizedBox(
        height: _toolBarHeight,
        width: Screen(context).width * 0.95,
        child: Align(
            alignment: Alignment.center,
            child: ListTile(
                trailing: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchTextController.text = "";
                    _displayMode = _DisplayMode.list;
                    _selectedNavBarItem = 2; // last visited
                    _pagingController.refresh();
                    setState(() {});
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
                    _pagingController.refresh();
                    setState(() {});
                  },
                ))));
  }

  BottomNavigationBar navBar(BuildContext context) {
    return BottomNavigationBar(
        currentIndex: _selectedNavBarItem,
        items: const [
          // new on osm
          BottomNavigationBarItem(icon: Icon(Icons.add), label: '*Neu*'),
          // 2 nearest
          BottomNavigationBarItem(icon: Icon(Icons.near_me), label: 'In Nähe'),
          // 1 alphabethic
          BottomNavigationBarItem(
              icon: Icon(Icons.timer), label: 'Zuletzt besucht'),
        ],
        onTap: (int id) {
          _selectedNavBarItem = id;

          switch (id) {
            /// create
            case 0:
              Navigator.pushNamed(context, AppRoutes.osm.route).then((_) {
                _pagingController.refresh();
                setState(() {});
              });

              break;

            /// last visited
            case 1:
              GPS.gps().then((GPS gps) {
                _gps = gps;
                _displayMode = _DisplayMode.nearest;
                _pagingController.refresh();
                setState(() {});
              });
              break;

            case 2:
              _displayMode = _DisplayMode.list;
              _pagingController.refresh();
              setState(() {});
              break;

            /// default view
            default:
              setState(() {});
            //
          }
        });
  }
}
