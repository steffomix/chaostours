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
import 'dart:math' as math;

///
import 'package:chaostours/logger.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/conf/app_routes.dart';
import 'package:chaostours/model/model_trackpoint_asset.dart';
import 'package:chaostours/model/model_trackpoint.dart';
import 'package:chaostours/view/system/app_base_widget.dart';
import 'package:chaostours/view/system/app_widgets.dart';
import 'package:chaostours/util.dart' as util;

enum TrackpointListArguments {
  none,
  location,
  locationGroup,
  user,
  userGroup,
  task,
  taskGroup;

  String arguments(int id) => '$id;$name';
}

class WidgetTrackPoints extends BaseWidget {
  const WidgetTrackPoints({super.key});

  @override
  State<WidgetTrackPoints> createState() => _WidgetTrackPointsState();
}

class _WidgetTrackPointsState extends BaseWidgetState<WidgetTrackPoints> {
  static final Logger logger = Logger.logger();
  TextEditingController tpSearch = TextEditingController();

  final _searchController = TextEditingController();
  final List<Widget> _loadedItems = [];
  final _isSelectActive = ValueNotifier<bool>(true);

  int getLimit() => 20;

  TrackpointListArguments mode = TrackpointListArguments.none;
  int? idLocation;
  int? idLocationGroup;
  int? idUser;
  int? idUserGroup;
  int? idTask;
  int? idTaskGroup;

  String trackpointSource = '';

  @override
  Future<void> initialize(BuildContext context, Object? args) async {
    if (args == null) {
      return;
    }
    String query = args.toString();
    try {
      final parts = query.split(';');
      int id = int.parse(parts[0]);
      if (id < 1) {
        throw 'id must be > 1, given is $id in "$query"';
      }
      String key = parts[1];
      if (key == TrackpointListArguments.location.name) {
        idLocation = id;
        trackpointSource = 'Location #$id';
      } else if (key == TrackpointListArguments.user.name) {
        idUser = id;
        trackpointSource = 'User #$id';
      } else if (key == TrackpointListArguments.task.name) {
        idTask = id;
        trackpointSource = 'Task #$id';
      } else if (key == TrackpointListArguments.locationGroup.name) {
        idLocationGroup = id;
        trackpointSource = 'Location group #$id';
      } else if (key == TrackpointListArguments.userGroup.name) {
        idUserGroup = id;
        trackpointSource = 'User group #$id';
      } else if (key == TrackpointListArguments.taskGroup.name) {
        idTaskGroup = id;
        trackpointSource = 'Task group #$id';
      } else {
        if (mounted) {
          Future.microtask(
            () => Navigator.pop(context),
          );
        }
        throw 'malformed query';
      }
    } catch (e, stk) {
      logger.error(' "$args": $e', stk);
    }
  }

  @override
  Future<void> resetLoader() async {
    _loadedItems.clear();
    await super.resetLoader();
    render();
  }

  BottomNavigationBar renderNavBar() {
    return BottomNavigationBar(
      currentIndex: 0,
      items: [
        const BottomNavigationBarItem(
            icon: Icon(Icons.cancel), label: 'Cancel'),
        BottomNavigationBarItem(
            icon: _isSelectActive.value
                ? const Icon(Icons.delete)
                : const Icon(Icons.visibility),
            label: _isSelectActive.value ? 'Show deleted' : 'Show active')
      ],
      onTap: (int id) {
        if (id == 0) {
          Navigator.pop(context);
        } else if (id == 1) {
          _isSelectActive.value = !_isSelectActive.value;
          resetLoader();
        }
      },
    );
  }

  @override
  Future<int> loadItems({int limit = 50, required int offset}) async {
    var items = await ModelTrackPoint.search(_searchController.text,
        isActive: _isSelectActive.value,
        idLocation: idLocation,
        idUser: idUser,
        idTask: idTask,
        idLocationGroup: idLocationGroup,
        idUserGroup: idUserGroup,
        idTaskGroup: idTaskGroup);
    if (_loadedItems.isNotEmpty) {
      _loadedItems.add(AppWidgets.divider());
    }
    _loadedItems.addAll(util.intersperse(
        const SizedBox(height: 20),
        items.map(
          (e) => renderItem(e),
        )));
    return items.length;
  }

  @override
  List<Widget> renderBody(BoxConstraints constraints) {
    return _loadedItems
        .map(
          (e) => SizedBox(width: constraints.maxWidth, child: e),
        )
        .toList();
  }

  @override
  Scaffold renderScaffold(Widget body) {
    return AppWidgets.scaffold(context,
        body: body, title: 'Trackpoints', navBar: renderNavBar());
  }

  Widget renderIsActive(ModelTrackPoint model) {
    return ListTile(
        leading: AppWidgets.checkbox(
          value: model.isActive,
          onChanged: (state) async {
            model.isActive = state ?? false;
            model.update();
          },
        ),
        title: const Text('Active & statistics'));
  }

  Widget renderItem(ModelTrackPoint model) {
    var divider = AppWidgets.divider();
    return Column(children: [
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Column(children: [
            renderId(model),
            renderDateTime(model),
            renderDuration(model),
            renderIsActive(model),
            divider,
            Align(
                alignment: Alignment.centerLeft,
                child: Text('OSM Addr: ${model.address}')),
            Column(
              children: [
                const Text('Location'),
                ...renderLocationList(trackpoint: model)
              ],
            ),
            divider,
            Column(
              children: [
                const Text('Users'),
                ...renderAssetList(
                    models: model.userModels, route: AppRoutes.editUser)
              ],
            ),
            divider,
            Column(
              children: [
                const Text('Tasks'),
                ...renderAssetList(
                    models: model.taskModels, route: AppRoutes.editTask)
              ],
            ),
            divider,
            const Text('Notes:'),
            Text(model.notes),
          ])),
    ]);
  }

  @override
  List<Widget> renderHeader(BoxConstraints constraints) {
    return [
      AppWidgets.searchTile(
          context: context,
          textController: _searchController,
          onChange: (_) => resetLoader()),
      Text(trackpointSource)
    ];
  }

  List<Widget> renderLocationList(
      {required ModelTrackPoint trackpoint, int index = 0}) {
    List<Widget> widgets = [];

    trackpoint.locationModels.sort(
      (a, b) {
        return a.distance(trackpoint.gps).compareTo(b.distance(trackpoint.gps));
      },
    );

    int index = 0;
    for (var model in trackpoint.locationModels) {
      int distance = GPS.distance(trackpoint.gps, model.model.gps).round();
      widgets.add(ListTile(
          leading: Icon(Icons.square, color: model.model.privacy.color),
          title: Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.editLocation.route,
                            arguments: model.id)
                        .then(
                      (value) {
                        render();
                      },
                    );
                  },
                  child: Text(
                    style: index > 0
                        ? null
                        : const TextStyle(
                            decoration: TextDecoration.underline,
                            fontWeight: FontWeight.bold),
                    '${distance}m: ${model.title}',
                  )))));
      index++;
    }
    return widgets;
  }

  List<Widget> renderAssetList(
      {required List<ModelTrackpointAsset> models, required AppRoutes route}) {
    List<Widget> widgets = [];
    for (var model in models) {
      widgets.add(Align(
        alignment: Alignment.centerLeft,
        child: model.notes.isEmpty
            ? TextButton(
                child: Text(model.title),
                onPressed: () async {
                  await Navigator.pushNamed(context, route.route,
                      arguments: model.id);
                  render();
                },
              )
            : ListTile(
                title: Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      child: Text(model.title),
                      onPressed: () async {
                        await Navigator.pushNamed(context, route.route,
                            arguments: model.id);
                        render();
                      },
                    )),
                subtitle: model.notes.isEmpty
                    ? null
                    : Text(model.notes,
                        style: Theme.of(context).textTheme.bodySmall),
              ),
      ));
    }
    return widgets;
  }

  Widget renderId(ModelTrackPoint model) {
    return Center(
        child: FilledButton(
      child: Text('#${model.id}: ${util.formatDate(model.timeStart)}'),
      onPressed: () async {
        await Navigator.pushNamed(context, AppRoutes.editTrackPoint.route,
            arguments: model.id);
        render();
      },
    ));
  }

  Widget renderDateTime(ModelTrackPoint model) {
    return Center(
        child: Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Transform.rotate(
            angle: 0,
            child: const Icon(
              Icons.start,
            )),
        Padding(
            padding: const EdgeInsets.fromLTRB(5, 1, 0, 0),
            child: Text(util.formatDateTime(model.timeStart))),
      ]),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Transform.rotate(
            angle: math.pi,
            child: const Icon(
              Icons.start,
            )),
        Padding(
            padding: const EdgeInsets.fromLTRB(5, 1, 0, 0),
            child: Text(util.formatDateTime(model.timeEnd))),
      ]),
    ]));
  }

  Widget renderDuration(ModelTrackPoint model) {
    return Center(child: Text(util.formatDuration(model.duration)));
  }
}
