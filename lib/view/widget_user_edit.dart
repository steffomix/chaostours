import 'package:chaostours/view/app_widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

///
import 'package:chaostours/logger.dart';
import 'package:chaostours/model/model_user.dart';

class WidgetUserEdit extends StatefulWidget {
  const WidgetUserEdit({super.key});

  @override
  State<WidgetUserEdit> createState() => _WidgetUserEdit();
}

class _WidgetUserEdit extends State<WidgetUserEdit> {
  static final Logger logger = Logger.logger<WidgetUserEdit>();

  ModelUser? _user;
  bool? _deleted;
  ValueNotifier<bool> modified = ValueNotifier<bool>(false);
  @override
  void dispose() {
    super.dispose();
  }

  void modify() {
    modified.value = true;
  }

  @override
  Widget build(BuildContext context) {
    final id = ModalRoute.of(context)!.settings.arguments as int;
    bool create = id <= 0;
    _user ??= create
        ? ModelUser(user: '', deleted: false, notes: '')
        : ModelUser.getUser(id);
    ModelUser user = _user!;
    _deleted ??= user.deleted;
    bool deleted = _deleted!;

    return AppWidgets.scaffold(context,
        navBar: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            fixedColor: AppColors.black.color,
            backgroundColor: AppColors.yellow.color,
            items: [
              // 0 alphabethic
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
              // 1 nearest
              const BottomNavigationBarItem(
                  icon: Icon(Icons.cancel), label: 'Abbrechen'),
            ],
            onTap: (int id) {
              if (id == 0) {
                ModelUser.update().then((_) => Navigator.pop(context));
              } else {
                Navigator.pop(context);
              }
            }),
        body: ListView(children: [
          /// username
          Container(
              padding: const EdgeInsets.all(10),
              child: TextField(
                decoration: const InputDecoration(label: Text('Name')),
                onChanged: ((value) {
                  modify();
                  user.user = value.trim();
                }),
                maxLines: 1,
                minLines: 1,
                controller: TextEditingController(text: user.user),
              )),

          /// notes
          Container(
              padding: const EdgeInsets.all(10),
              child: TextField(
                  decoration: const InputDecoration(label: Text('Notizen')),
                  maxLines: null,
                  minLines: 3,
                  controller: TextEditingController(text: user.notes),
                  onChanged: (value) {
                    user.notes = value.trim();

                    modify();
                  })),

          /// deleted
          ListTile(
              title: const Text('Deaktiviert / gelöscht'),
              subtitle: const Text(
                'Definiert ob diese Person gelistet und auswählbar ist.'
                '\nBereits zugewiesenes Personal bleibt grundsätzlich sichtbar.',
                softWrap: true,
              ),
              leading: Checkbox(
                value: deleted,
                onChanged: (val) {
                  user.deleted = val ?? false;
                  modify();
                  setState(() {
                    _deleted = val;
                  });
                },
              ))
        ]));
  }
}
