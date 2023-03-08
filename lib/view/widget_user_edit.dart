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

  int userId = 0;
  ModelUser _user = ModelUser(user: '', deleted: false, notes: '');
  // checkbox
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
    final userId = ModalRoute.of(context)!.settings.arguments as int;
    if (userId > 0) {
      _user = ModelUser.getUser(userId).clone();
    }
    _deleted ??= _user.deleted;
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
              if (id == 0 && modified.value) {
                if (_user.user.trim().isEmpty) {
                  _user.user = '#${_user.id}';
                }
                if (userId == 0) {
                  ModelUser.insert(_user).then((int id) {
                    if (_user.user.isEmpty) {
                      _user.user = '#${_user.id}';
                      ModelUser.update().then((_) {
                        Navigator.pop(context);
                      });
                      return;
                    }
                  });
                  Navigator.pop(context);
                } else {
                  ModelUser.update(_user).then((_) => Navigator.pop(context));
                }
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
                  _user.user = value.trim();
                }),
                maxLines: 1,
                minLines: 1,
                controller: TextEditingController(text: _user.user),
              )),

          /// notes
          Container(
              padding: const EdgeInsets.all(10),
              child: TextField(
                  decoration: const InputDecoration(label: Text('Notizen')),
                  maxLines: null,
                  minLines: 3,
                  controller: TextEditingController(text: _user.notes),
                  onChanged: (value) {
                    _user.notes = value.trim();

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
                  _user.deleted = val ?? false;
                  modify();
                  setState(() {
                    _deleted = val;
                  });
                },
              ))
        ]));
  }
}
