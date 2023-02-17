import 'package:chaostours/widget/widgets.dart';
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

    var deleted = _deleted!;

    return AppWidgets.scaffold(context,
        body: ListView(children: [
          ///
          /// ok/add button
          Center(
              child: IconButton(
            icon: const Icon(Icons.done, size: 50),
            onPressed: () {
              if (alias.alias.isEmpty) {
                alias.alias = 'Alias #${alias.id}';
              }
              alias.deleted = deleted;
              ModelAlias.write();
              Navigator.pop(context);
              Navigator.pushNamed(context, AppRoutes.listAlias.route);
            },
          )),

          /// aliasname
          Container(
              padding: const EdgeInsets.all(10),
              child: TextField(
                decoration: const InputDecoration(label: Text('Alias/Adresse')),
                onChanged: ((value) {
                  alias.alias = value;
                }),
                maxLines: 1,
                minLines: 1,
                controller: TextEditingController(text: alias.alias),
              )),

          /// gps
          Container(
              padding: const EdgeInsets.all(10),
              child: ElevatedButton(
                child: Text('GPS: ${alias.lat}, ${alias.lon}'),
                onPressed: () {
                  ///
                  Navigator.pushNamed(context, AppRoutes.osm.route,
                      arguments: alias.id);
                },
              )),

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
                decoration:
                    const InputDecoration(label: Text('Radius in meter')),
                onChanged: ((value) {
                  try {
                    alias.radius = int.parse(value);
                  } catch (e) {
                    //
                  }
                }),
                maxLines: 1,
                minLines: 1,
                controller:
                    TextEditingController(text: alias.radius.toString()),
              )),

          /// deleted
          ListTile(
              title: const Text('Deaktiviert / gelöscht'),
              subtitle: const Text(
                'Definiert ob diese Aufgabe gelistet und auswählbar ist',
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
