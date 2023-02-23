import 'package:chaostours/view/app_widgets.dart';
import 'package:flutter/material.dart';

///
import 'package:chaostours/logger.dart';
import 'package:chaostours/model/model_alias.dart';
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
    ModelAlias.update();
    super.dispose();
  }

  Widget title(BuildContext context, alias) {
    var lines =
        (alias.alias.length / 50).round() + (alias.alias.split('\n').length);
    return TextField(
        //style: const TextStyle(fontSize: 10),
        decoration: const InputDecoration(
            hintText: 'Alias Bezeichnung', border: InputBorder.none),
        minLines: lines,
        maxLines: lines + 2,
        controller: TextEditingController(text: alias.alias),
        onChanged: ((value) {
          if (value.isNotEmpty) {
            alias.alias = value;
          }
        }));
  }

  Widget subtitle(BuildContext context, alias) {
    var lines =
        (alias.alias.length / 50).round() + (alias.alias.split('\n').length);
    return TextField(
        style: const TextStyle(fontSize: 12),
        decoration: const InputDecoration(border: InputBorder.none),
        minLines: lines,
        maxLines: lines + 2,
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
            arguments: alias.id);
      },
    );
  }

  Widget body(BuildContext context) {
    _id = ModalRoute.of(context)?.settings.arguments as int? ?? 0;
    var list = <ModelAlias>[];
    var select = _listMode == 1
        ? ModelAlias.nextAlias(_gps, true)
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
    var searchWidget = TextField(
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

    ///
    widgets.add(searchWidget);
    widgets.add(AppWidgets.divider());

    ///
    for (var alias in list) {
      widgets.add(ListTile(
        trailing: btnInfo(context, alias),
        title: title(context, alias),
        subtitle: subtitle(context, alias),
      ));
      widgets.add(AppWidgets.divider());
    }
    return ListView(children: widgets);
  }

  BottomNavigationBar navBar(BuildContext context) {
    return BottomNavigationBar(
        selectedFontSize: 14,
        unselectedFontSize: 14,
        backgroundColor: AppColors.yellow.color,
        selectedItemColor: AppColors.black.color,
        unselectedItemColor: AppColors.black.color,
        items: const [
          // 0 alphabethic
          BottomNavigationBarItem(
              icon: Icon(Icons.timer), label: 'Zuletzt besucht'),
          // 1 nearest
          BottomNavigationBarItem(icon: Icon(Icons.near_me), label: 'In Nähe'),
        ],
        onTap: (int id) {
          _listMode = id;
          if (id == 1) {
            GPS.gps().then((GPS gps) {
              _gps = gps;
              setState(() {});
            });
          } else {
            setState(() {});
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    return AppWidgets.scaffold(context,
        body: body(context), navBar: navBar(context));
  }
}
