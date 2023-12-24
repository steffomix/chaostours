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

import 'package:chaostours/conf/app_user_settings.dart';
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

class WidgetAliasEdit extends StatefulWidget {
  const WidgetAliasEdit({super.key});

  @override
  State<WidgetAliasEdit> createState() => _WidgetAliasEdit();
}

class _WidgetAliasEdit extends State<WidgetAliasEdit> {
  // ignore: unused_field
  static final Logger logger = Logger.logger<WidgetAliasEdit>();

  static const double _paddingSide = 10.0;

  final _addressController = TextEditingController();
  final _addressUndoController = UndoHistoryController();

  final _notesController = TextEditingController();
  final _notesUndoController = UndoHistoryController();

  final _radiusController = TextEditingController();
  final _radiusUndoController = UndoHistoryController();

  final _visibility = ValueNotifier<bool>(false);
  ModelAlias? _modelAlias;

  List<ModelAliasGroup> _groups = [];

  void initialize(ModelAlias model) {
    _modelAlias = model;
    if (_addressController.text != model.title) {
      _addressController.text = model.title;
    }
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
    var address =
        (await Address(gps).lookup(OsmLookupConditions.onUserCreateAlias));
    var model = ModelAlias(
        gps: gps,
        lastVisited: DateTime.now(),
        title: address.alias,
        description: address.description);
    await model.insert();
    return model;
  }

  Future<ModelAlias?> loadAlias(int? id) async {
    var model = await ModelAlias.byId(id ?? 0);
    if (model == null) {
      if (mounted) {
        Navigator.pop(context);
      }
    }
    var ids = (await model?.groupIds()) ?? [];
    _groups = ids.isEmpty ? [] : await ModelAliasGroup.byIdList(ids);
    return model;
  }

  @override
  Widget build(BuildContext context) {
    int? id = ModalRoute.of(context)?.settings.arguments as int?;

    return FutureBuilder<ModelAlias?>(
      future: loadAlias(id),
      builder: (context, snapshot) {
        Widget? loading = AppWidgets.checkSnapshot(context, snapshot);
        if (loading == null) {
          var model = snapshot.data!;
          initialize(model);
          return scaffold(body(model));
        } else {
          return AppWidgets.scaffold(context,
              body: AppWidgets.loading(const Text('Loading Alias...')));
        }
      },
    );
  }

  Widget scaffold(Widget body) {
    return AppWidgets.scaffold(context,
        title: 'Edit Alias',
        navBar: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            items: const [
              BottomNavigationBarItem(
                  icon: Icon(Icons.add), label: 'Create new Alias'),
              BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Route'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.cancel), label: 'Cancel'),
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

      ListTile(
          dense: true,
          trailing: ValueListenableBuilder<UndoHistoryValue>(
            valueListenable: _addressUndoController,
            builder: (context, value, child) {
              return IconButton(
                icon: const Icon(Icons.undo),
                onPressed: value.canUndo
                    ? () {
                        _addressUndoController.undo();
                      }
                    : null,
              );
            },
          ),
          title: Container(
              padding: const EdgeInsets.all(_paddingSide),
              child: TextField(
                undoController: _addressUndoController,
                decoration: const InputDecoration(label: Text('Alias Address')),
                onChanged: ((value) {
                  alias.title = value;
                  alias.update();
                }),
                maxLines: 3,
                minLines: 3,
                controller: _addressController,
              ))),

      /// notes
      ListTile(
          dense: true,
          trailing: ValueListenableBuilder<UndoHistoryValue>(
            valueListenable: _notesUndoController,
            builder: (context, value, child) {
              return IconButton(
                icon: const Icon(Icons.undo),
                onPressed: value.canUndo
                    ? () {
                        _notesUndoController.undo();
                      }
                    : null,
              );
            },
          ),
          title: Container(
              padding: const EdgeInsets.all(_paddingSide),
              child: TextField(
                undoController: _notesUndoController,
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(label: Text('Notes')),
                maxLines: null,
                minLines: 3,
                controller: _notesController,
                onChanged: (value) {
                  alias.description = value.trim();
                  alias.update();
                },
              ))),
      AppWidgets.divider(),

      /// GPS
      ListTile(
        trailing: IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () {
              Clipboard.setData(
                  ClipboardData(text: '${alias.gps.lat}, ${alias.gps.lon}'));
            }),
        title: const Text('GPS Location'),
        subtitle: Padding(
            padding: const EdgeInsets.all(_paddingSide),
            child: ElevatedButton(
              child: Text(
                  'Latitude, Longitude:\n${alias.gps.lat}, ${alias.gps.lon}'),
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.osm.route,
                        arguments: alias.id)
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
            )),
      ),

      /// radius
      ListTile(
          dense: true,
          trailing: ValueListenableBuilder<UndoHistoryValue>(
            valueListenable: _radiusUndoController,
            builder: (context, value, child) {
              return IconButton(
                icon: const Icon(Icons.undo),
                onPressed: value.canUndo
                    ? () {
                        _radiusUndoController.undo();
                      }
                    : null,
              );
            },
          ),
          title: Container(
              padding: const EdgeInsets.all(_paddingSide),
              child: TextField(
                undoController: _radiusUndoController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('[0-9]')),
                ],
                decoration:
                    const InputDecoration(label: Text('Radius in meter.')),
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
              ))),

      AppWidgets.divider(),

      // groups
      Padding(
          padding: const EdgeInsets.all(_paddingSide),
          child: ListTile(
            trailing: IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {
                  Navigator.pushNamed(
                          context, AppRoutes.listAliasGroupsFromAlias.route,
                          arguments: _modelAlias?.id)
                      .then(
                    (value) {
                      render();
                    },
                  );
                }),
            title: const Text('Groups', style: TextStyle(height: 2)),
            subtitle: Column(
                children: _groups.map(
              (model) {
                return ElevatedButton(
                  child: ListTile(
                    title: Text(model.title),
                    subtitle: Text(model.description),
                  ),
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.editAliasGroup.route,
                            arguments: model.id)
                        .then(
                      (value) => render(),
                    );
                  },
                );
              },
              // ignore: unnecessary_to_list_in_spreads
            ).toList()),
          )),

      AppWidgets.divider(),

      /// type
      Container(
          padding: const EdgeInsets.all(_paddingSide),
          child: Column(children: [
            const ListTile(
              title: Text('Typ'),
              subtitle: Text(
                'Definiert ob und wie Haltepunkte verarbeitet werden.',
                softWrap: true,
              ),
            ),
            ListTile(
                title: Container(
                    color: AliasVisibility.public.color,
                    padding: const EdgeInsets.all(3),
                    child: const Text('  Public',
                        style: TextStyle(
                          color: Colors.white,
                        ))),
                subtitle: const Text('This Alias supports all app futures.'),
                leading: ValueListenableBuilder(
                    valueListenable: _visibility,
                    builder: (context, value, child) {
                      return Radio<AliasVisibility>(
                          value: AliasVisibility.public,
                          groupValue: alias.visibility,
                          onChanged: (AliasVisibility? val) {
                            setStatus(val);
                          });
                    })),
            ListTile(
                title: Container(
                    color: AliasVisibility.privat.color,
                    padding: const EdgeInsets.all(3),
                    child: const Text('  Private',
                        style: TextStyle(
                          color: Colors.white,
                        ))),
                subtitle: const Text(
                    'This Alias is reduced to app internal futures only.'),
                leading: ValueListenableBuilder(
                    valueListenable: _visibility,
                    builder: (context, value, child) {
                      return Radio<AliasVisibility>(
                          value: AliasVisibility.privat,
                          groupValue: alias.visibility,
                          onChanged: (AliasVisibility? val) {
                            setStatus(val);
                          });
                    })),
            ListTile(
                title: Container(
                    color: AliasVisibility.restricted.color,
                    padding: const EdgeInsets.all(3),
                    child: const Text('  Restricted ',
                        style: TextStyle(
                          color: Colors.white,
                        ))),
                subtitle: const Text(
                    'This Alias functionality is reduced to be visible in apps map.'),
                leading: ValueListenableBuilder(
                  valueListenable: _visibility,
                  builder: (context, value, child) {
                    return Radio<AliasVisibility>(
                        value: AliasVisibility.restricted,
                        groupValue: alias.visibility,
                        onChanged: (AliasVisibility? state) {
                          _visibility.value = !_visibility.value;
                          setStatus(state);
                        });
                  },
                ))
          ])),
      AppWidgets.divider(),

      /// deleted
      ListTile(
          title: const Text('Aktive if checked'),
          subtitle: const Text(
            'If inactive this Alias has no functionality and is visible in garbage list only.',
            softWrap: true,
          ),
          leading: AppWidgets.checkbox(
            value: alias.isActive,
            onChanged: (state) async {
              alias.isActive = state ?? false;
              await alias.update();
            },
          ))
    ]);
  }

  void render() {
    if (mounted) {
      setState(() {});
    }
  }

  void setStatus(AliasVisibility? state) {
    _modelAlias?.visibility = (state ?? AliasVisibility.restricted);
    _modelAlias?.update();
    _visibility.value = !_visibility.value;
  }
}
