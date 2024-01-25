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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

///
import 'package:chaostours/conf/app_user_settings.dart';
import 'package:chaostours/statistics/location_statistics.dart';
import 'package:chaostours/view/system/app_widgets.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/address.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/model/model_location.dart';
import 'package:chaostours/model/model_location_group.dart';
import 'package:chaostours/view/trackpoint/widget_trackpoint_list.dart';
import 'package:chaostours/conf/app_routes.dart';

class WidgetLocationEdit extends StatefulWidget {
  const WidgetLocationEdit({super.key});

  @override
  State<WidgetLocationEdit> createState() => _WidgetLocationEdit();
}

class _WidgetLocationEdit extends State<WidgetLocationEdit> {
  // ignore: unused_field
  static final Logger logger = Logger.logger<WidgetLocationEdit>();

  static const double _paddingSide = 10.0;

  final _addressController = TextEditingController();
  final _addressUndoController = UndoHistoryController();

  final _notesController = TextEditingController();
  final _notesUndoController = UndoHistoryController();

  final _radiusController = TextEditingController();
  final _radiusUndoController = UndoHistoryController();

  final _privacy = ValueNotifier<bool>(false);
  ModelLocation? _modelLocation;

  List<ModelLocationGroup> _groups = [];

  void initialize(ModelLocation model) {
    _modelLocation = model;
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

  Future<ModelLocation> createLocation() async {
    var gps = await GPS.gps();
    var address =
        (await Address(gps).lookup(OsmLookupConditions.onUserCreateLocation));
    var model = ModelLocation(
        gps: gps,
        lastVisited: DateTime.now(),
        title: address.address,
        description: address.addressDetails);
    await model.insert();
    return model;
  }

  Future<ModelLocation?> loadLocation(int? id) async {
    var model = await ModelLocation.byId(id ?? 0);
    if (model == null) {
      if (mounted) {
        Navigator.pop(context);
      }
    }
    var ids = (await model?.groupIds()) ?? [];
    _groups = ids.isEmpty ? [] : await ModelLocationGroup.byIdList(ids);
    return model;
  }

  @override
  Widget build(BuildContext context) {
    int? id = ModalRoute.of(context)?.settings.arguments as int?;

    return FutureBuilder<ModelLocation?>(
      future: loadLocation(id),
      builder: (context, snapshot) {
        Widget? loading = AppWidgets.checkSnapshot(context, snapshot);
        if (loading == null) {
          var model = snapshot.data!;
          initialize(model);
          return scaffold(body(model));
        } else {
          return AppWidgets.scaffold(context,
              body: AppWidgets.loading(const Text('Loading location...')));
        }
      },
    );
  }

  Widget scaffold(Widget body) {
    return AppWidgets.scaffold(context,
        title: 'Edit location',
        navBar: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            items: const [
              BottomNavigationBarItem(
                  icon: Icon(Icons.add), label: 'Create new location'),
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
                    _modelLocation!.gps.lat, _modelLocation!.gps.lon);
              } else if (id == 2) {
                Navigator.pop(context);
              }
            }),
        body: body);
  }

  Widget body(ModelLocation location) {
    return ListView(children: [
      /// Trackpoints button
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: FilledButton(
                  onPressed: () => Navigator.pushNamed(
                      context, AppRoutes.listTrackpoints.route,
                      arguments: TrackpointListArguments.location
                          .arguments(location.id)),
                  child: const Text('Trackpoints'))),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: FilledButton(
                  onPressed: () async {
                    var stats = await LocationStatistics.statistics(location);

                    if (mounted) {
                      AppWidgets.statistics(context, stats: stats,
                          reload: (DateTime start, DateTime end) async {
                        return await LocationStatistics.statistics(stats.model,
                            start: start, end: end);
                      });
                    }
                  },
                  child: const Text('Statistics')))
        ],
      ),

      /// location name
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
                decoration:
                    const InputDecoration(label: Text('Location Address')),
                onChanged: ((value) {
                  location.title = value;
                  location.update();
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
                  location.description = value.trim();
                  location.update();
                },
              ))),
      AppWidgets.divider(),

      /// GPS
      ListTile(
        trailing: IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () {
              Clipboard.setData(ClipboardData(
                  text: '${location.gps.lat}, ${location.gps.lon}'));
            }),
        title: const Text('GPS Location'),
        subtitle: Padding(
            padding: const EdgeInsets.all(_paddingSide),
            child: FilledButton(
              child: Text(
                  'Latitude, Longitude:\n${location.gps.lat}, ${location.gps.lon}'),
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.osm.route,
                        arguments: location.id)
                    .then(
                  (value) {
                    ModelLocation.byId(location.id).then(
                      (ModelLocation? model) {
                        setState(() {
                          _modelLocation = model;
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
                    location.radius = int.parse(value);
                    location.update();
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
                  Navigator.pushNamed(context,
                          AppRoutes.listLocationGroupsFromLocation.route,
                          arguments: _modelLocation?.id)
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
                return ListTile(
                  title: Text(model.title),
                  subtitle: Text(model.description),
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
                'Defines location and trackpoints privacy level and functionalty.',
                softWrap: true,
              ),
            ),
            ListTile(
                title: Container(
                    color: LocationPrivacy.public.color,
                    padding: const EdgeInsets.all(3),
                    child: const Text('  Public',
                        style: TextStyle(
                          color: Colors.white,
                        ))),
                subtitle: const Text('This location supports all app futures:\n'
                    '- Send notification if permission granted\n- Lookup address if permitted\n- make a database record\n- publish to Device Calendar if activated in App Settings.'),
                leading: ValueListenableBuilder(
                    valueListenable: _privacy,
                    builder: (context, value, child) {
                      return Radio<LocationPrivacy>(
                          value: LocationPrivacy.public,
                          groupValue: location.privacy,
                          onChanged: (LocationPrivacy? val) {
                            setStatus(val);
                          });
                    })),
            ListTile(
                title: Container(
                    color: LocationPrivacy.privat.color,
                    padding: const EdgeInsets.all(3),
                    child: const Text('  Private',
                        style: TextStyle(
                          color: Colors.white,
                        ))),
                subtitle: const Text(
                    'This location is reduced to app internal futures only:\n'
                    '- Send notification if permission granted\n- Lookup address if permitted\n- make a database record'),
                leading: ValueListenableBuilder(
                    valueListenable: _privacy,
                    builder: (context, value, child) {
                      return Radio<LocationPrivacy>(
                          value: LocationPrivacy.privat,
                          groupValue: location.privacy,
                          onChanged: (LocationPrivacy? val) {
                            setStatus(val);
                          });
                    })),
            ListTile(
                title: Container(
                    color: LocationPrivacy.restricted.color,
                    padding: const EdgeInsets.all(3),
                    child: const Text('  Restricted ',
                        style: TextStyle(
                          color: Colors.white,
                        ))),
                subtitle: const Text(
                    'This location functionality is reduced to be visible in apps map and:\n'
                    '- Send notification if permission granted'),
                leading: ValueListenableBuilder(
                  valueListenable: _privacy,
                  builder: (context, value, child) {
                    return Radio<LocationPrivacy>(
                        value: LocationPrivacy.restricted,
                        groupValue: location.privacy,
                        onChanged: (LocationPrivacy? state) {
                          _privacy.value = !_privacy.value;
                          setStatus(state);
                        });
                  },
                )),
            ListTile(
                title: Container(
                    color: const Color.fromARGB(255, 0, 0, 0),
                    padding: const EdgeInsets.all(3),
                    child: const Text('  None ',
                        style: TextStyle(
                          color: Colors.white,
                        ))),
                subtitle: const Text(
                    'This location functionality is reduced to be visible in apps map and:\n'
                    '- does nothing else'),
                leading: ValueListenableBuilder(
                  valueListenable: _privacy,
                  builder: (context, value, child) {
                    return Radio<LocationPrivacy>(
                        value: LocationPrivacy.none,
                        groupValue: location.privacy,
                        onChanged: (LocationPrivacy? state) {
                          _privacy.value = !_privacy.value;
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
            'If inactive this location has no functionality and is visible in garbage list only.',
            softWrap: true,
          ),
          leading: AppWidgets.checkbox(
            value: location.isActive,
            onChanged: (state) async {
              location.isActive = state ?? false;
              await location.update();
            },
          ))
    ]);
  }

  void render() {
    if (mounted) {
      setState(() {});
    }
  }

  void setStatus(LocationPrivacy? state) {
    _modelLocation?.privacy = (state ?? LocationPrivacy.restricted);
    _modelLocation?.update();
    _privacy.value = !_privacy.value;
  }
}
