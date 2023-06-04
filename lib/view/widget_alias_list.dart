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
import 'package:chaostours/model/model_alias.dart';
import 'package:chaostours/model/model_trackpoint.dart';
import 'package:chaostours/gps.dart';

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

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
  }

  Widget title(BuildContext context, ModelAlias alias) {
    var lines =
        (alias.title.length / 50).round() + (alias.title.split('\n').length);
    int dur = DateTime.now().difference(alias.lastVisited).inDays;
    int count = ModelTrackPoint.countAlias(alias.id);
    return ListTile(
        subtitle:
            Text('${count}x, ${count == 0 ? 'noch nie' : 'vor $dur Tage'}'),
        title: TextField(
            readOnly: true,
            decoration: const InputDecoration(
                hintText: 'Alias Bezeichnung', border: InputBorder.none),
            minLines: lines,
            maxLines: lines + 2,
            controller: TextEditingController(text: alias.title),
            onChanged: ((value) {
              if (value.isNotEmpty) {
                alias.title = value;
              }
            })));
  }

  Widget subtitle(BuildContext context, ModelAlias alias) {
    var lines =
        (alias.title.length / 50).round() + (alias.title.split('\n').length);
    return TextField(
        readOnly: true,
        style: const TextStyle(fontSize: 12),
        decoration:
            const InputDecoration(border: InputBorder.none, isDense: true),
        minLines: 1,
        maxLines: lines,
        controller: TextEditingController(text: alias.notes),
        onChanged: ((value) {
          alias.notes = value;
        }));
  }

  Widget btnInfo(BuildContext context, alias) {
    return IconButton(
      icon: Icon(Icons.info_outline_rounded,
          size: 30,
          color: alias.deleted
              ? Colors.black
              : AppColors.aliasStatusColor(alias.status)),
      onPressed: () {
        Navigator.pushNamed(context, AppRoutes.listAliasTrackpoints.route,
                arguments: alias.id)
            .then((_) {
          setState(() {});
        });
      },
    );
  }

  Widget searchWidget(BuildContext context) {
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

  Widget body(BuildContext context) {
    var list = <ModelAlias>[];
    var select = _listMode == 1
        ? ModelAlias.nextAlias(gps: _gps, all: true)
        : ModelAlias.lastVisitedAlias(true);

    for (var alias in select) {
      if (search.isEmpty) {
        list.add(alias);
      } else if (alias.title.toLowerCase().contains(search.toLowerCase()) ||
          alias.notes.toLowerCase().contains(search.toLowerCase())) {
        list.add(alias);
      }
    }

    var widgets = <Widget>[];

    ///
    widgets.add(searchWidget(context));
    widgets.add(AppWidgets.divider());

    return ListView.builder(
        itemCount: list.length + 1,
        itemBuilder: (BuildContext context, int id) {
          if (id == 0) {
            return ListBody(
                children: [searchWidget(context), AppWidgets.divider()]);
          }
          var alias = list[id - 1];
          return ListBody(children: [
            alias.notes.trim().isEmpty
                ? ListTile(
                    trailing: btnInfo(context, alias),
                    title: title(context, alias))
                : ListTile(
                    trailing: btnInfo(context, alias),
                    title: title(context, alias),
                    subtitle: subtitle(context, alias),
                  ),
            AppWidgets.divider()
          ]);
        });
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
    return AppWidgets.scaffold(context,
        body: body(context),
        navBar: navBar(context),
        appBar: AppBar(title: const Text('Alias List')));
  }
}
