import 'package:flutter/material.dart';

///
import 'package:chaostours/globals.dart';
import 'package:chaostours/view/app_widgets.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/model/model_user.dart';
import 'package:chaostours/checkbox_controller.dart';
import 'package:chaostours/cache.dart';
//import 'package:chaostours/app_settings.dart';

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

  ValueNotifier<bool> modified = ValueNotifier<bool>(false);

  void modify() {
    modified.value = true;

    setState(() {});
  }

  Set<int> preselectedUsers = Globals.preselectedUsers;

  @override
  void dispose() {
    super.dispose();
  }

  Widget searchWidget(BuildContext context) {
    return Column(children: [
      TextField(
        controller: controller,
        minLines: 1,
        maxLines: 1,
        decoration: const InputDecoration(
            icon: Icon(Icons.search, size: 30), border: InputBorder.none),
        onChanged: (value) {
          search = value;
          setState(() {});
        },
      ),

      ///
      Container(child: dropdownUser(context)),
      Container(padding: const EdgeInsets.all(5), child: AppWidgets.divider()),
    ]);
  }

  bool dropdownUserIsOpen = false;
  Widget dropdownUser(context) {
    /// render selected users
    List<String> userList = [];
    for (var id in preselectedUsers) {
      var user = ModelUser.getUser(id);
      if (!user.deleted) {
        userList.add(ModelUser.getUser(id).user);
      }
    }
    String users =
        userList.isNotEmpty ? '- ${userList.join('\n- ')}' : 'Keine Ausgewählt';

    /// dropdown menu botten with selected users
    List<Widget> items = [
      ElevatedButton(
        child: Column(children: [
          Center(
              child: Container(
                  padding: const EdgeInsets.all(5),
                  child: const Text('Vorausgewähltes Personal',
                      style: TextStyle(fontSize: 16)))),
          ListTile(trailing: const Icon(Icons.menu), title: Text(users)),
        ]),
        onPressed: () {
          dropdownUserIsOpen = !dropdownUserIsOpen;
          setState(() {});
        },
      ),
      !dropdownUserIsOpen
          ? const SizedBox.shrink()
          : Column(children: userCheckboxes(context))
    ];
    return ListBody(children: items);
  }

  List<Widget> userCheckboxes(context) {
    var checkBoxes = <Widget>[];
    for (var m in ModelUser.getAll()) {
      if (!m.deleted) {
        checkBoxes.add(createCheckbox(CheckboxController(
            idReference: m.id,
            referenceList: preselectedUsers.toList(),
            deleted: m.deleted,
            title: m.user,
            subtitle: m.notes)));
      }
    }
    return checkBoxes;
  }

  /// render multiple checkboxes
  Widget createCheckbox(CheckboxController model) {
    TextStyle style = TextStyle(
        color: model.enabled ? Colors.black : Colors.grey,
        decoration:
            model.deleted ? TextDecoration.lineThrough : TextDecoration.none);

    return ListTile(
      subtitle: model.subtitle.trim().isEmpty
          ? null
          : Text(model.subtitle, style: const TextStyle(color: Colors.grey)),
      title: Text(
        model.title,
        style: style,
      ),
      leading: Checkbox(
        value: model.checked,
        onChanged: (bool? checked) {
          if (checked ?? false) {
            preselectedUsers.add(model.idReference);
          } else {
            preselectedUsers.remove(model.idReference);
          }
          modify();
          setState(
            () {
              model.handler()?.call();
            },
          );
        },
      ),
      onTap: () {
        setState(
          () {
            model.handler()?.call();
          },
        );
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
              BottomNavigationBarItem(
                  icon: ValueListenableBuilder(
                      valueListenable: modified,
                      builder: ((context, value, child) {
                        return Icon(Icons.done,
                            size: 30,
                            color: modified.value == true
                                ? AppColors.green.color
                                : AppColors.white54.color);
                      })),
                  label: 'Speichern'),
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
                Globals.savePreselectedUsers().then((_) {
                  modified.value = false;
                  dropdownUserIsOpen = false;
                  setState(() {});
                });
              }
              if (id == 1) {
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
