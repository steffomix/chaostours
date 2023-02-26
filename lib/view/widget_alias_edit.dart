import 'package:chaostours/view/app_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:android_intent_plus/android_intent.dart';
import 'package:chaostours/gps.dart';

///
import 'package:chaostours/logger.dart';
import 'package:chaostours/model/model_alias.dart';

class WidgetAliasEdit extends StatefulWidget {
  const WidgetAliasEdit({super.key});

  @override
  State<WidgetAliasEdit> createState() => _WidgetAliasEdit();
}

class _WidgetAliasEdit extends State<WidgetAliasEdit> {
  static final Logger logger = Logger.logger<WidgetAliasEdit>();

  ValueNotifier<bool> modified = ValueNotifier<bool>(false);
  late ModelAlias alias;
  TextEditingController addressController = TextEditingController();
  TextEditingController notesController = TextEditingController();
  TextEditingController radiusController = TextEditingController();

  @override
  void dispose() {
    modified.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final id = ModalRoute.of(context)!.settings.arguments as int;

    ///
    alias = ModelAlias.getAlias(id).clone();

    addressController.text = alias.alias;
    notesController.text = alias.notes;
    radiusController.text = alias.radius.toString();

    return AppWidgets.scaffold(context,
        navBar: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            fixedColor: AppColors.black.color,
            backgroundColor: AppColors.yellow.color,
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
            onTap: (int id) {
              if (id == 0) {
                Navigator.pushNamed(context, AppRoutes.osm.route, arguments: 0)
                    .then((_) {
                  setState(() {});
                });
              } else if (id == 1) {
                var gps = GPS.lastGps!;
                var lat = gps.lat;
                var lon = gps.lon;
                var lat1 = alias.lat;
                var lon1 = alias.lon;
                var url = 'https://www.google.com/maps/dir/?'
                    'api=1&origin=$lat%2c$lon&destination=$lat1%2c$lon1&'
                    'travelmode=driving';

                final intent = AndroidIntent(
                    action: 'action_view',
                    data: url,
                    package: 'com.google.android.apps.maps');
                intent.launch();
              } else if (id == 2) {
                ModelAlias.update(alias).then((_) {
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
                  alias.alias = value;
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
                          'Latitude/Breitengrad:\n${alias.lat}\n\nLongitude/Längengrad:\n${alias.lon}')),
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.osm.route,
                            arguments: alias.id)
                        .then(
                      (value) {
                        setState(() {});
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
                  alias.notes = value.trim();
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
                          backgroundColor: AppColors.aliasPubplic.color,
                        )),
                    subtitle: const Text(
                      'Ereignisse die diesen Ort betreffen können gespeichert und '
                      'z.B. automatisch in einem privaten oder öffentlichen Kalender publiziert werden.',
                      softWrap: true,
                    ),
                    leading: Radio<AliasStatus>(
                        value: AliasStatus.public,
                        groupValue: alias.status,
                        onChanged: (AliasStatus? val) =>
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
                    leading: Radio<AliasStatus>(
                        value: AliasStatus.privat,
                        groupValue: alias.status,
                        onChanged: (AliasStatus? val) =>
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
                    leading: Radio<AliasStatus>(
                        value: AliasStatus.restricted,
                        groupValue: alias.status,
                        onChanged: (AliasStatus? val) =>
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
                value: alias.deleted,
                onChanged: (val) {
                  alias.deleted = val ?? false;
                  modify();
                  setState(() {});
                },
              ))
        ]));
  }

  void modify() {
    modified.value = true;
  }

  void setStatus(BuildContext context, AliasStatus? val) {
    alias.status = val ?? AliasStatus.restricted;
    modified.value = true;
    setState(() {});
  }
}
