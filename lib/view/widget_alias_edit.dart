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
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';

import 'package:chaostours/gps.dart';

///
import 'package:chaostours/logger.dart';
import 'package:chaostours/model/model_alias.dart';
import 'package:chaostours/conf/app_routes.dart';
import 'package:chaostours/conf/app_colors.dart';

class WidgetAliasEdit extends StatefulWidget {
  const WidgetAliasEdit({super.key});

  @override
  State<WidgetAliasEdit> createState() => _WidgetAliasEdit();
}

class _WidgetAliasEdit extends State<WidgetAliasEdit> {
  // ignore: unused_field
  static final Logger logger = Logger.logger<WidgetAliasEdit>();

  ModelAlias? _alias;
  ValueNotifier<bool> modified = ValueNotifier<bool>(false);
  TextEditingController addressController = TextEditingController();
  TextEditingController notesController = TextEditingController();
  TextEditingController radiusController = TextEditingController();

  String loadingMsg = '';

  @override
  void dispose() {
    modified.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final id = ModalRoute.of(context)!.settings.arguments as int;

    ///
    if (_alias == null) {
      loadingMsg = 'Loading Alias #$id';
      ModelAlias.byId(id).then(
        (ModelAlias? model) {
          if (model != null) {
            setState(() {
              _alias = model;
            });
          }
        },
      ).onError((error, stackTrace) {
        loadingMsg = 'load alias on initialize build: $error';
        logger.error(loadingMsg, stackTrace);
      });
      return AppWidgets.loading(loadingMsg);
    }
    ModelAlias alias = _alias!;
    addressController.text = alias.title;
    notesController.text = alias.description;
    radiusController.text = alias.radius.toString();

    return AppWidgets.scaffold(context,
        navBar: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            items: [
              const BottomNavigationBarItem(
                  icon: Icon(Icons.add), label: 'Neu'),
              const BottomNavigationBarItem(
                  icon: Icon(Icons.map), label: 'Route'),
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
            onTap: (int id) async {
              if (id == 0) {
                Navigator.pushNamed(context, AppRoutes.osm.route, arguments: 0)
                    .then((_) {
                  setState(() {});
                });
              } else if (id == 1) {
                var gps = await GPS.gps();
                await GPS.launchGoogleMaps(
                    gps.lat, gps.lon, alias.gps.lat, alias.gps.lon);
              } else if (id == 2) {
                alias.update().then((_) {
                  Fluttertoast.showToast(msg: 'Alias updated');
                  Navigator.pop(context);
                });
              } else if (id == 3) {
                Navigator.pop(context);
              }
            }),
        body: ListView(children: [
          /// aliasname
          Container(
              padding: const EdgeInsets.all(10),
              child: TextField(
                decoration: const InputDecoration(label: Text('Alias/Adresse')),
                onChanged: ((value) {
                  alias.title = value;
                  modify();
                }),
                maxLines: 3,
                minLines: 3,
                controller: addressController,
              )),

          /// gps
          Column(children: [
            const Text('Alias GPS Koordinaten', softWrap: true),
            Container(
                padding: const EdgeInsets.all(10),
                child: ElevatedButton(
                  child: ListTile(
                      leading: const Icon(
                        Icons.near_me,
                        size: 40,
                      ),
                      title: Text(
                          'Latitude/Breitengrad:\n${alias.gps.lat}\n\nLongitude/Längengrad:\n${alias.gps.lon}')),
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.osm.route,
                            arguments: alias.id)
                        .then(
                      (value) {
                        ModelAlias.byId(alias.id).then(
                          (ModelAlias? model) {
                            setState(() {
                              _alias = model;
                            });
                          },
                        );
                      },
                    );
                  },
                ))
          ]),
          AppWidgets.divider(),

          /// notes
          Container(
              padding: const EdgeInsets.all(10),
              child: TextField(
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(label: Text('Notizen')),
                maxLines: null,
                minLines: 3,
                controller: notesController,
                onChanged: (value) {
                  modify();
                  alias.description = value.trim();
                },
              )),

          /// radius
          Container(
              padding: const EdgeInsets.all(10),
              child: TextField(
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('[0-9]')),
                ],
                decoration: const InputDecoration(
                    label: Text('Gültigkeitsbereich (Radius) in meter.')),
                onChanged: ((value) {
                  try {
                    alias.radius = int.parse(value);
                    modify();
                  } catch (e) {
                    //
                  }
                }),
                maxLines: 1, //
                minLines: 1,
                controller: radiusController,
              )),

          /// type
          Container(
              padding: const EdgeInsets.all(10),
              child: Column(children: [
                const ListTile(
                  title: Text('Typ'),
                  subtitle: Text(
                    'Definiert ob und wie Haltepunkte verarbeitet werden.',
                    softWrap: true,
                  ),
                ),
                ListTile(
                    title: Text('Öffentlich',
                        style: TextStyle(
                          backgroundColor: AppColors.aliasPublic.color,
                        )),
                    subtitle: const Text(
                      'Ereignisse die diesen Ort betreffen können gespeichert und '
                      'z.B. automatisch in einem privaten oder öffentlichen Kalender publiziert werden.',
                      softWrap: true,
                    ),
                    leading: Radio<AliasVisibility>(
                        value: AliasVisibility.public,
                        groupValue: alias.visibility,
                        onChanged: (AliasVisibility? val) =>
                            setStatus(context, val))),
                ListTile(
                    title: Text('Privat',
                        style: TextStyle(
                          backgroundColor: AppColors.aliasPrivate.color,
                        )),
                    subtitle: const Text(
                      'Ereignisse die diesen Ort betreffen verlassen ihr Gerät nicht, '
                      'es sei denn sie exportieren z.B. die Datenbank, machen Screenshots etc. '
                      'und geben die Informationen selst an Dritte weiter.',
                      softWrap: true,
                    ),
                    leading: Radio<AliasVisibility>(
                        value: AliasVisibility.privat,
                        groupValue: alias.visibility,
                        onChanged: (AliasVisibility? val) =>
                            setStatus(context, val))),
                ListTile(
                    title: Text('Geheim',
                        style: TextStyle(
                          backgroundColor: AppColors.aliasRestricted.color,
                        )),
                    subtitle: const Text(
                      'An diesem Ort werden keine Haltepunkte aufgezeichnent, als wäre das Gerät ausgeschaltet. '
                      'Das bedeutet, wenn Sie diesen Ort erreichen, halten und wieder losfahren, '
                      'fehlt die gesamte Aufzeichnung vom losfahren zu diesem Ort bis zum erreichen des nächsten Ortes. '
                      'Die daraus resultierende Aufzeichnung erweckt den Eindruck, als hätten sie sich von Ort A, '
                      'über Ort B(geheim) nach Ort C über einen bisher unbekannten Subraum transportiert.',
                      softWrap: true,
                    ),
                    leading: Radio<AliasVisibility>(
                        value: AliasVisibility.restricted,
                        groupValue: alias.visibility,
                        onChanged: (AliasVisibility? val) =>
                            setStatus(context, val)))
              ])),
          AppWidgets.divider(),

          /// deleted
          ListTile(
              title: const Text('Deaktiviert / gelöscht'),
              subtitle: const Text(
                'Wenn deaktiviert bzw. gelöscht, wird dieser Alias behandelt wie ein "gelöschter" Fakebook Account.',
                softWrap: true,
              ),
              leading: Checkbox(
                value: alias.isActive,
                onChanged: (val) {
                  alias.isActive = val ?? false;
                  modify();
                  setState(() {});
                },
              ))
        ]));
  }

  void modify() {
    modified.value = true;
  }

  void setStatus(BuildContext context, AliasVisibility? val) {
    _alias?.visibility = (val ?? AliasVisibility.restricted);
    modified.value = true;
    setState(() {});
  }
}
