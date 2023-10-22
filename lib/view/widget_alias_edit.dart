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

import 'package:chaostours/gps.dart';
import 'package:chaostours/address.dart';

///
import 'package:chaostours/logger.dart';
import 'package:chaostours/model/model_alias.dart';
import 'package:chaostours/model/model_alias_group.dart';
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

  ModelAlias? _modelAlias;
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();
  final _radiusController = TextEditingController();
  List<ModelAliasGroup> _groups = [];

  void initialize(ModelAlias model) {
    _modelAlias = model;
    _addressController.text = model.title;
    _notesController.text = model.description;
    _radiusController.text = model.radius.toString();
  }

  String loadingMsg = '';

  @override
  void dispose() {
    super.dispose();
  }

  Future<ModelAlias> createAlias() async {
    var gps = await GPS.gps();
    var address = (await Address(gps).lookupAddress()).toString();
    var model =
        ModelAlias(gps: gps, lastVisited: DateTime.now(), title: address);
    await ModelAlias.insert(model);
    return model;
  }

  Future<ModelAlias?> loadAlias(int? id) async {
    if (id == null) {
      return await createAlias();
    }
    var model = await ModelAlias.byId(id);
    if (model == null) {
      if (mounted) {
        Navigator.pop(context);
      }
    }
    _groups = await model?.groups() ?? [];
    return model;
  }

  @override
  Widget build(BuildContext context) {
    int? id = ModalRoute.of(context)?.settings.arguments as int?;

    return FutureBuilder<ModelAlias?>(
      future: loadAlias(id),
      builder: (context, snapshot) {
        Widget? loading = AppWidgets.checkSnapshot(snapshot);
        if (loading == null) {
          var model = snapshot.data!;
          initialize(model);
          _modelAlias = model;
          _addressController.text = model.title;
          _notesController.text = model.description;
          _radiusController.text = model.radius.toString();
          return scaffold(body(model));
        } else {
          return AppWidgets.scaffold(context,
              body: AppWidgets.loading('Loading Alias...'));
        }
      },
    );
  }

  Widget scaffold(Widget body) {
    return AppWidgets.scaffold(context,
        navBar: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.add), label: 'Neu'),
              BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Route'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.cancel), label: 'Abbrechen'),
            ],
            onTap: (int id) async {
              if (id == 0) {
                Navigator.pushNamed(context, AppRoutes.osm.route).then((_) {
                  render();
                });
              } else if (id == 1) {
                var gps = await GPS.gps();
                await GPS.launchGoogleMaps(gps.lat, gps.lon,
                    _modelAlias!.gps.lat, _modelAlias!.gps.lon);
              } else if (id == 2) {
                Navigator.pop(context);
              }
            }),
        body: body);
  }

  Widget body(ModelAlias alias) {
    return ListView(children: [
      /// aliasname
      Container(
          padding: const EdgeInsets.all(10),
          child: TextField(
            decoration: const InputDecoration(label: Text('Alias/Adresse')),
            onChanged: ((value) {
              alias.title = value;
              alias.update();
            }),
            maxLines: 3,
            minLines: 3,
            controller: _addressController,
          )),

      /// notes
      Container(
          padding: const EdgeInsets.all(10),
          child: TextField(
            keyboardType: TextInputType.multiline,
            decoration: const InputDecoration(label: Text('Notizen')),
            maxLines: null,
            minLines: 3,
            controller: _notesController,
            onChanged: (value) {
              alias.description = value.trim();
              alias.update();
            },
          )),
      AppWidgets.divider(),

      ElevatedButton(
        child: Column(children: [
          const Text('GPS'),
          ListTile(
              leading: const Icon(
                Icons.near_me,
                size: 40,
              ),
              title: Text('Latitude/Breitengrad:\n${alias.gps.lat}\n\n'
                  'Longitude/Längengrad:\n${alias.gps.lon}'))
        ]),
        onPressed: () {
          Navigator.pushNamed(context, AppRoutes.osm.route, arguments: alias.id)
              .then(
            (value) {
              ModelAlias.byId(alias.id).then(
                (ModelAlias? model) {
                  setState(() {
                    _modelAlias = model;
                  });
                },
              );
            },
          );
        },
      ),
      AppWidgets.divider(),

      Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: ElevatedButton(
              child: Column(children: [
                const Text('Groups', style: TextStyle(height: 2)),
                ..._groups.map(
                  (model) {
                    return ListTile(
                      title: Text(
                        model.title,
                      ),
                      subtitle: Text(model.description),
                    );
                  },
                ).toList()
              ]),
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.listAliasGroup.route,
                        arguments: _modelAlias?.id)
                    .then(
                  (value) {
                    render();
                  },
                );
              })),

      AppWidgets.divider(),

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
                alias.update();
              } catch (e) {
                //
              }
            }),
            maxLines: 1, //
            minLines: 1,
            controller: _radiusController,
          )),

      AppWidgets.divider(),

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
                    onChanged: (AliasVisibility? val) {
                      setStatus(context, val);
                    })),
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
                    onChanged: (AliasVisibility? val) {
                      setStatus(context, val);
                    })),
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
                    onChanged: (AliasVisibility? val) {
                      setStatus(context, val);
                    }))
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
              setState(() {});
              alias.update();
              render();
            },
          ))
    ]);
  }

  void render() {
    if (mounted) {
      setState(() {});
    }
  }

  void setStatus(BuildContext context, AliasVisibility? val) {
    _modelAlias?.visibility = (val ?? AliasVisibility.restricted);
    _modelAlias?.update().then(
      (value) {
        render();
      },
    );
  }
}
