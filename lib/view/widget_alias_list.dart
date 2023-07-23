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

import 'package:chaostours/view/app_widgets.dart';
import 'package:flutter/material.dart';

///
import 'package:chaostours/logger.dart';
import 'package:chaostours/conf/app_routes.dart';
import 'package:chaostours/conf/app_colors.dart';
import 'package:chaostours/model/model.dart';
import 'package:chaostours/model/model_alias.dart';
import 'package:chaostours/model/model_trackpoint.dart';
import 'package:chaostours/gps.dart';

class _ViewData {
  final List<ModelAlias> models;

  _ViewData({required this.models});

  static Future<_ViewData> load() async {
    List<ModelAlias> models = await ModelAlias.select();
    var data = _ViewData(models: await _countTrackPoints(models));
    return data;
  }

  static Future<_ViewData> search(String search) async {
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
}

class WidgetAliasList extends StatefulWidget {
  const WidgetAliasList({super.key});

  @override
  State<WidgetAliasList> createState() => _WidgetAliasList();
}

class _WidgetAliasList extends State<WidgetAliasList> {
  // ignore: unused_field
  static final Logger logger = Logger.logger<WidgetAliasList>();

  int _listMode = 0;
  GPS _gps = GPS(0, 0);
  String search = '';
  static TextEditingController controller = TextEditingController();

  List<ModelAlias> aliasModels = [];

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
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
    return TextField(
      controller: controller,
      minLines: 1,
      maxLines: 1,
      decoration: const InputDecoration(
          icon: Icon(Icons.search, size: 30), border: InputBorder.none),
      onChanged: (value) {
        search = value;
        setState(() {});
      },
    );
  }

  int selectedNavBarItem = 0;
  BottomNavigationBar navBar(BuildContext context) {
    return BottomNavigationBar(
        currentIndex: selectedNavBarItem,
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
          selectedNavBarItem = id;
          _listMode = id;

          switch (id) {
            /// create
            case 0:
              Navigator.pushNamed(context, AppRoutes.osm.route, arguments: 0)
                  .then((_) {
                setState(() {});
              });
              break;

            /// last visited
            case 1:
              GPS.gps().then((GPS gps) {
                _gps = gps;
                setState(() {});
              });
              break;

            /// default view
            default:
              setState(() {});
            //
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    var builder = FutureBuilder<_ViewData>(
        future: search.isEmpty ? _ViewData.load() : _ViewData.search(search),
        builder: (BuildContext context, AsyncSnapshot<_ViewData> snapshot) {
          var data = snapshot.data!;
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

    return AppWidgets.scaffold(context,
        body: builder,
        navBar: navBar(context),
        appBar: AppBar(title: const Text('Alias List')));
  }
}
