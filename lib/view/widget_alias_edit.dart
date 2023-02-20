import 'package:chaostours/view/app_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  bool? _deleted;
  ModelAlias? _alias;
  AliasStatus? _status;
  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final id = ModalRoute.of(context)!.settings.arguments as int;

    ///
    _alias ??= ModelAlias.getAlias(id);
    var alias = _alias!;
    _deleted ??= alias.deleted;
    _status ??= alias.status;

    var deleted = _deleted!;

    return AppWidgets.scaffold(context,
        navBar: BottomNavigationBar(
            items: const [
              // 0 alphabethic
              BottomNavigationBarItem(
                  icon: Icon(Icons.done), label: 'Speichern'),
              // 1 nearest
              BottomNavigationBarItem(
                  icon: Icon(Icons.cancel), label: 'Abbrechen'),
            ],
            onTap: (int id) {
              if (id == 1) {
                ModelAlias.update();
                Navigator.pop(context);
              } else if (id == 0) {
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
                }),
                maxLines: 3,
                minLines: 3,
                controller: TextEditingController(text: alias.alias),
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
                    ///
                    Navigator.pushNamed(context, AppRoutes.osm.route,
                        arguments: alias.id);
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
                controller: TextEditingController(text: alias.notes),
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
                  } catch (e) {
                    //

                  }
                }),
                onSubmitted: (value) {
                  alias.radius = int.parse(value);
                  ModelAlias.update();
                },
                maxLines: 1, //
                minLines: 1,
                controller:
                    TextEditingController(text: alias.radius.toString()),
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
                    title: const Text('Öffentlich'),
                    subtitle: const Text(
                      'Ereignisse die diesen Ort betreffen können gespeichert und '
                      'z.B. automatisch in einem privaten oder öffentlichen Kalender publiziert werden.',
                      softWrap: true,
                    ),
                    leading: Radio<AliasStatus>(
                        value: AliasStatus.public,
                        groupValue: _status,
                        onChanged: (AliasStatus? val) {
                          _status = val;
                          setState(() {});
                        })),
                ListTile(
                    title: const Text('Privat'),
                    subtitle: const Text(
                      'Ereignisse die diesen Ort betreffen verlassen ihr Gerät nicht, '
                      'es sei denn sie exportieren z.B. die Datenbank, machen Screenshots etc. '
                      'und geben die Informationen selst an Dritte weiter.',
                      softWrap: true,
                    ),
                    leading: Radio<AliasStatus>(
                        value: AliasStatus.privat,
                        groupValue: _status,
                        onChanged: (AliasStatus? val) {
                          _status = val;
                          setState(() {});
                        })),
                ListTile(
                    title: const Text('Geheim'),
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
                        groupValue: _status,
                        onChanged: (AliasStatus? val) {
                          _status = val;
                          setState(() {});
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
                value: deleted,
                onChanged: (val) {
                  setState(() {
                    _deleted = val;
                  });
                  alias.deleted = val ?? false;
                },
              ))
        ]));
  }
}
