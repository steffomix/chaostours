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

import 'package:chaostours/screen.dart';
import 'package:chaostours/view/app_widgets.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

///
import 'package:chaostours/view/sliver_header.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/conf/app_routes.dart';
import 'package:chaostours/conf/app_colors.dart';
import 'package:chaostours/model/model_alias.dart';
import 'package:chaostours/gps.dart';

enum _DisplayMode {
  list,
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
  String _search = "";

  GPS? _gps;

  // height of seasrch field container
  final double _toolBarHeight = 70;
  String search = '';
  static TextEditingController controller = TextEditingController();
  List<ModelAlias> aliasModels = [];

  // items per page
  static const int _limit = 3;

  final PagingController<int, ModelAlias> _pagingController =
      PagingController(firstPageKey: 0);

  Future<void> _fetchPage(int offset) async {
    try {
      final newItems = await (_search.isEmpty
          ? _displayMode == _DisplayMode.nearest
              ? ModelAlias.nextAlias(gps: _gps!, offset: offset, limit: _limit)
              : ModelAlias.select(offset: offset, limit: _limit)
          : ModelAlias.search(_search, offset: offset));
      final isLastPage = newItems.length < _limit;
      if (isLastPage) {
        _pagingController.appendLastPage(newItems);
      } else {
        final nextPageKey = offset + newItems.length;
        _pagingController.appendPage(newItems, nextPageKey);
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
    _pagingController.addPageRequestListener(
      (offset) {
        _fetchPage(offset);
      },
    );
    super.initState();
  }

  ///
  ///
  ///
  ///
  ///
  ///
  ///
  ///
  ///
  ///
  ///

  @override
  Widget build(BuildContext context) {
    /*
    var body = PagedListView<int, DbRow>.separated(
      separatorBuilder: (context, index) => const Divider(),
      pagingController: _pagingController,
      builderDelegate: PagedChildBuilderDelegate<DbRow>(
        itemBuilder: (context, item, index) =>
            ListTile(leading: Text(item.name)),
      ),
    );
    */

    var body = CustomScrollView(
      slivers: <Widget>[
        SliverPersistentHeader(
            pinned: true,
            delegate: SliverHeader(
                widget: searchWidget(), //Text('Test'),
                toolBarHeight: _toolBarHeight,
                closedHeight: 0,
                openHeight: 0)),
        PagedSliverList<int, ModelAlias>.separated(
          separatorBuilder: (BuildContext context, int i) => const Divider(),
          pagingController: _pagingController,
          builderDelegate: PagedChildBuilderDelegate<ModelAlias>(
            itemBuilder: (context, item, index) =>
                Center(child: ListTile(leading: Text(item.id.toString()))),
          ),
        ),
      ],
    );
    return AppWidgets.scaffold(context,
        body: body,
        navBar: navBar(context),
        appBar: AppBar(title: const Text('Alias List')));
/* 
    var builder = FutureBuilder<_ViewData>(
        future: search.isEmpty ? _ViewData.load() : _ViewData.search(search),
        builder: (BuildContext context, AsyncSnapshot<_ViewData> snapshot) {
          if (snapshot.data == null) {
            return AppWidgets.loading('Loading ...');
          }
          var data = snapshot.data!;
          if (data.models.isEmpty) {
            return AppWidgets.loading('No Data found');
          }
          var itemCount = data.models.length;
          var models = data.models;
          return AppWidgets.checkSnapshot(snapshot) ??
              ListView.builder(
                  itemCount: itemCount + 1,
                  itemBuilder: ((BuildContext context, int id) {
                    if (id == 0) {
                      return ListBody(
                          children: [searchWidget(), AppWidgets.divider()]);
                    }
                    var model = models[id - 1];
                    return ListBody(children: [
                      model.description.trim().isEmpty
                          ? ListTile(
                              trailing: btnInfo(context, model),
                              title: title(model))
                          : ListTile(
                              trailing: btnInfo(context, model),
                              title: title(model),
                              subtitle: subtitle(model),
                            ),
                      AppWidgets.divider()
                    ]);
                  }));
        });
 */
  }

  Widget title(ModelAlias model) {
    var lines =
        (model.title.length / 50).round() + (model.title.split('\n').length);
    int dur = DateTime.now().difference(model.lastVisited).inDays;
    int count = model.trackPointCount;
    return ListTile(
        subtitle:
            Text('${count}x, ${count == 0 ? 'noch nie' : 'vor $dur Tage'}'),
        title: TextField(
            readOnly: true,
            decoration: const InputDecoration(
                hintText: 'Alias Bezeichnung', border: InputBorder.none),
            minLines: lines,
            maxLines: lines + 2,
            controller: TextEditingController(text: model.title),
            onChanged: ((value) {
              if (value.isNotEmpty) {
                model.title = value;
              }
            })));
  }

  Widget subtitle(ModelAlias model) {
    var lines =
        (model.title.length / 50).round() + (model.title.split('\n').length);
    return TextField(
        readOnly: true,
        style: const TextStyle(fontSize: 12),
        decoration:
            const InputDecoration(border: InputBorder.none, isDense: true),
        minLines: 1,
        maxLines: lines,
        controller: TextEditingController(text: model.description),
        onChanged: ((value) {
          model.description = value;
        }));
  }

  Widget btnInfo(BuildContext context, ModelAlias model) {
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
                  onPressed: () {},
                ),
                title: TextField(
                  controller: controller,
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
                    _search = value;
                    _displayMode = _DisplayMode.list;
                    _selectedNavBarItem = 2; // last visited
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
              GPS.gps().then(
                (GPS gps) async {
                  int count = await ModelAlias.count();
                  await ModelAlias.insert(ModelAlias(
                      gps: gps,
                      lastVisited: DateTime.now(),
                      title: "Alias $count"));
                  _pagingController.refresh();
                  setState(() {});
                },
              );
              /*
              Navigator.pushNamed(context, AppRoutes.osm.route, arguments: 0)
                  .then((_) {
                setState(() {});
              });
              */
              break;

            /// last visited
            case 1:
              ModelAlias.count().then((value) => print(value));
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



/*
class _ViewData {
  static int modelCount = 0;
  final List<ModelAlias> models;

  static late GPS gps;

  _ViewData({required this.models});

  static Future<_ViewData> load({int offset = 0}) async {
    //await Future.delayed(Duration(seconds: 2));
    await _getPageData();
    modelCount = await ModelAlias.count();
    List<ModelAlias> models = await ModelAlias.select(offset: offset);
    var data = _ViewData(models: await _countTrackPoints(models));
    return data;
  }

  static Future<_ViewData> search(String search) async {
    await _getPageData();
    List<ModelAlias> models = await ModelAlias.search(search);
    return _ViewData(models: await _countTrackPoints(models));
  }

  static Future<List<ModelAlias>> _countTrackPoints(
      List<ModelAlias> models) async {
    for (var model in models) {
      model.trackPointCount = await model.countTrackPoints();
    }
    return models;
  }

  static Future<void> _getPageData() async {
    gps = await GPS.gps();
    return Future(() => null);
  }
}
*/