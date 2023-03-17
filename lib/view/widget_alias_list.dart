import 'package:chaostours/view/app_widgets.dart';
import 'package:flutter/material.dart';

///
import 'package:chaostours/logger.dart';
import 'package:chaostours/model/model_alias.dart';
import 'package:chaostours/model/model_trackpoint.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/screen.dart';

class WidgetAliasList extends StatefulWidget {
  const WidgetAliasList({super.key});

  @override
  State<WidgetAliasList> createState() => _WidgetAliasList();
}

class _WidgetAliasList extends State<WidgetAliasList> {
  static final Logger logger = Logger.logger<WidgetAliasList>();

  int _id = 0;
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
        (alias.alias.length / 50).round() + (alias.alias.split('\n').length);
    int dur = DateTime.now().difference(alias.lastVisited).inDays;
    int count = ModelTrackPoint.countTask(alias.id);
    return ListTile(
        subtitle:
            Text('${count}x, ${count == 0 ? 'noch nie' : 'vor $dur Tage'}'),
        title: TextField(
            readOnly: true,
            decoration: const InputDecoration(
                hintText: 'Alias Bezeichnung', border: InputBorder.none),
            minLines: lines,
            maxLines: lines + 2,
            controller: TextEditingController(text: alias.alias),
            onChanged: ((value) {
              if (value.isNotEmpty) {
                alias.alias = value;
              }
            })));
  }

  Widget subtitle(BuildContext context, alias) {
    var lines =
        (alias.alias.length / 50).round() + (alias.alias.split('\n').length);
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
          size: 30, color: AppColors.aliasStatusColor(alias.status)),
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
    _id = ModalRoute.of(context)?.settings.arguments as int? ?? 0;
    var list = <ModelAlias>[];
    var select = _listMode == 1
        ? ModelAlias.nextAlias(gps: _gps, all: true)
        : ModelAlias.lastVisitedAlias(true);

    for (var alias in select) {
      if (search.isEmpty) {
        list.add(alias);
      } else if (alias.alias.toLowerCase().contains(search.toLowerCase()) ||
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
        fixedColor: AppColors.black.color,
        backgroundColor: AppColors.yellow.color,
        items: const [
          // new on osm
          BottomNavigationBarItem(icon: Icon(Icons.add), label: '*Neu*'),

          // 1 alphabethic
          BottomNavigationBarItem(
              icon: Icon(Icons.timer), label: 'Zuletzt besucht'),
          // 2 nearest
          BottomNavigationBarItem(icon: Icon(Icons.near_me), label: 'In Nähe'),
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
        body: body(context), navBar: navBar(context));
  }
}
