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


class WidgetUserEdit extends StatefulWidget {
  const WidgetUserEdit({super.key});

  @override
  State<WidgetUserEdit> createState() => _WidgetUserEdit();
}

class _WidgetUserEdit extends State<WidgetUserEdit> {
  @override
  Widget build(BuildContext context) {
    return AppWidgets.scaffold(context,
        body: AppWidgets.loading('Widget under construction'));
  }
  /* 
  // ignore: unused_field
  static final Logger logger = Logger.logger<WidgetUserEdit>();

  int userId = 0;
  late ModelUser _user;
  // checkbox
  ValueNotifier<bool> modified = ValueNotifier<bool>(false);
  bool initialized = false;

  @override
  void dispose() {
    super.dispose();
  }

  void modify() {
    modified.value = true;
  }

  @override
  Widget build(BuildContext context) {
    if (!initialized) {
      userId = (ModalRoute.of(context)?.settings.arguments ?? 0) as int;
      if (userId > 0) {
        _user = ModelUser.getModel(userId).clone();
      } else {
        _user = ModelUser(title: '', notes: '', deleted: false);
      }
      initialized = true;
    }
    return AppWidgets.scaffold(context,
        appBar: AppBar(title: const Text('Arbeiter bearbeiten')),
        navBar: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
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
                if (_user.title.trim().isEmpty) {
                  _user.title = '#${_user.id}';
                }
                if (userId == 0) {
                  ModelUser.insert(_user).then((int id) {
                    if (_user.title.isEmpty) {
                      _user.title = '#${_user.id}';
                      ModelUser.update().then((_) {
                        Navigator.pop(context);
                      });
                      return;
                    }
                    Fluttertoast.showToast(msg: 'User created');
                  });
                  Navigator.pop(context);
                } else {
                  ModelUser.update(_user).then((_) {
                    Navigator.pop(context);
                    Fluttertoast.showToast(msg: 'User updated');
                  });
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
                  _user.title = value.trim();
                }),
                maxLines: 1,
                minLines: 1,
                controller: TextEditingController(text: _user.title),
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
                value: _user.deleted,
                onChanged: (val) {
                  _user.deleted = val ?? false;
                  modify();
                  setState(() {
                    //_deleted = val;
                  });
                },
              ))
        ]));
  } */
}
