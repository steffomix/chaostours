import 'package:chaostours/view/app_widgets.dart';
import 'package:flutter/material.dart';

///
import 'package:chaostours/logger.dart';
import 'package:chaostours/model/model_alias.dart';
import 'package:chaostours/gps.dart';

class WidgetAliasList extends StatefulWidget {
  const WidgetAliasList({super.key});

  @override
  State<WidgetAliasList> createState() => _WidgetAliasList();
}

class _WidgetAliasList extends State<WidgetAliasList> {
  static final Logger logger = Logger.logger<WidgetAliasList>();

  int _listMode = 0;
  GPS _gps = GPS(0, 0);
  String search = '';
  TextEditingController controller = TextEditingController();

  @override
  void dispose() {
    super.dispose();
  }

  Widget body() {
    var list = <ModelAlias>[];

    for (var alias in _listMode == 1
        ? ModelAlias.nextAlias(_gps, true)
        : ModelAlias.getAll()) {
      if (search.isEmpty) {
        list.add(alias);
      } else if (alias.alias.toLowerCase().contains(search.toLowerCase()) ||
          alias.notes.toLowerCase().contains(search.toLowerCase())) {
        list.add(alias);
      }
    }

    return ListView(children: [
      Center(
          child: IconButton(
        icon: const Icon(Icons.add, size: 40),
        onPressed: () {
          Navigator.pushNamed(context, AppRoutes.osm.route);
        },
      )),
      TextField(
        controller: controller,
        minLines: 1,
        maxLines: 1,
        decoration: const InputDecoration(icon: Icon(Icons.search)),
        onChanged: (value) {
          search = value;
          setState(() {});
        },
      ),
      ...list.map((ModelAlias alias) {
        return ListTile(
            title: Text(alias.alias),
            subtitle: Text(alias.notes),
            leading: IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {
                  Navigator.pushNamed(context, AppRoutes.editAlias.route,
                      arguments: alias.id);
                }));
      }).toList()
    ]);
  }

  BottomNavigationBar navBar() {
    return BottomNavigationBar(
        items: const [
          // 0 alphabethic
          BottomNavigationBarItem(icon: Icon(Icons.sort_by_alpha), label: 'x'),
          // 1 nearest
          BottomNavigationBarItem(icon: Icon(Icons.near_me), label: 'x'),
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
    return AppWidgets.scaffold(context, body: body(), navBar: navBar());
  }
}
