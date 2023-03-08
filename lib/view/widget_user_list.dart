import 'dart:ui';

import 'package:chaostours/view/app_widgets.dart';
import 'package:flutter/material.dart';

///
import 'package:chaostours/logger.dart';
import 'package:chaostours/model/model_user.dart';

class WidgetUserList extends StatefulWidget {
  const WidgetUserList({super.key});

  @override
  State<WidgetUserList> createState() => _WidgetUserList();
}

class _WidgetUserList extends State<WidgetUserList> {
  static final Logger logger = Logger.logger<WidgetUserList>();

  TextEditingController controller = TextEditingController();
  String search = '';
  bool showDeleted = false;

  @override
  void dispose() {
    super.dispose();
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

  Widget usersWidget(context) {
    /// search
    List<ModelUser> userlist = [];
    for (var item in ModelUser.getAll().reversed) {
      if (!showDeleted && item.deleted) {
        continue;
      }
      if (search.trim().isEmpty) {
        userlist.add(item);
      } else {
        if (item.user.contains(search) || item.notes.contains(search)) {
          userlist.add(item);
        }
      }
    }

    return ListView.builder(
        itemCount: userlist.length + 1,
        itemBuilder: (BuildContext context, int id) {
          if (id == 0) {
            return searchWidget(context);
          } else {
            ModelUser user = userlist[id - 1];
            return ListBody(children: [
              ListTile(
                  title: Text(user.user,
                      style: TextStyle(
                          decoration: user.deleted
                              ? TextDecoration.lineThrough
                              : TextDecoration.none)),
                  subtitle: Text(user.notes),
                  trailing: IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () {
                        Navigator.pushNamed(context, AppRoutes.editUser.route,
                                arguments: user.id)
                            .then((_) => setState(() {}));
                      })),
              AppWidgets.divider()
            ]);
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    return AppWidgets.scaffold(context,
        body: usersWidget(context),
        navBar: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            backgroundColor: AppColors.yellow.color,
            fixedColor: AppColors.black.color,
            items: [
              const BottomNavigationBarItem(
                  icon: Icon(Icons.add), label: 'Neu'),
              BottomNavigationBarItem(
                  icon: const Icon(Icons.remove_red_eye),
                  label: showDeleted
                      ? 'Gelöschte verbergen'
                      : 'Gelöschte anzeigen'),
            ],
            onTap: (int id) {
              if (id == 0) {
                Navigator.pushNamed(context, AppRoutes.editUser.route,
                        arguments: 0)
                    .then((_) => setState(() {}));
              } else {
                showDeleted = !showDeleted;
                setState(() {});
              }
            }));
  }
}
