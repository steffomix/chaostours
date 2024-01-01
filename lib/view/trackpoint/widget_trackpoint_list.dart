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

///
import 'package:chaostours/logger.dart';
import 'package:chaostours/conf/app_routes.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/model/model.dart';
import 'package:chaostours/model/model_alias.dart';
import 'package:chaostours/model/model_trackpoint.dart';
import 'package:chaostours/view/app_base_widget.dart';
import 'package:chaostours/view/app_widgets.dart';
import 'package:chaostours/util.dart' as util;

String argumentsTrackpointAliasList(int aliasId) {
  return '$aliasId;${_TrackpointListMode.alias.name}';
}

String argumentsTrackpointUserList(int userId) {
  return '$userId;${_TrackpointListMode.user.name}';
}

String argumentsTrackpointTaskList(int taskId) {
  return '$taskId;${_TrackpointListMode.task.name}';
}

enum _TrackpointListMode {
  none,
  alias,
  user,
  task;
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

  int getLimit() => 20;

  _TrackpointListMode mode = _TrackpointListMode.none;
  int? idAlias;
  int? idUser;
  int? idTask;

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
      if (key == _TrackpointListMode.alias.name) {
        idAlias = id;
      } else if (key == _TrackpointListMode.user.name) {
        idUser = id;
      } else if (key == _TrackpointListMode.task.name) {
        idTask = id;
      } else {
        throw 'malformed query';
      }
    } catch (e, stk) {
      logger.error(' "$args": $e', stk);
    }
  }

  @override
  Future<int> loadItems({int limit = 50, required int offset}) async {
    var items = await ModelTrackPoint.search(_searchController.text,
        idAlias: idAlias, idUser: idUser, idTask: idTask);
    if (_loadedItems.isNotEmpty) {
      _loadedItems.add(AppWidgets.divider());
    }
    _loadedItems.addAll(util.intersperse(
        AppWidgets.divider(),
        items.map(
          (e) => renderItem(e),
        )));
    return items.length;
  }

  @override
  Future<void> resetLoader() async {
    _loadedItems.clear();
    await super.resetLoader();
    render();
  }

  @override
  List<Widget> renderHeader(BoxConstraints constraints) {
    return [
      AppWidgets.searchTile(
          context: context,
          textController: _searchController,
          onChange: (_) => resetLoader())
    ];
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
    return AppWidgets.scaffold(context, body: body, title: 'Trackpoints');
  }

  List<Widget> renderAliasList(
      {required ModelTrackPoint trackpoint,
      required List<ModelAlias> models,
      int index = 0}) {
    List<Widget> widgets = [];
    models = models.map(
      (model) {
        model.sortDistance = GPS.distance(model.gps, trackpoint.gps).round();
        return model;
      },
    ).toList();
    models.sort(
      (a, b) {
        return a.sortDistance.compareTo(b.sortDistance);
      },
    );

    int index = 0;
    for (var model in models) {
      widgets.add(ListTile(
          leading: Icon(Icons.square, color: model.privacy.color),
          title: Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.editAlias.route,
                            arguments: model.id)
                        .then(
                      (value) {
                        render();
                      },
                    );
                  },
                  child: Text(
                    style: index > 1
                        ? null
                        : const TextStyle(
                            decoration: TextDecoration.underline,
                            fontWeight: FontWeight.bold),
                    model.title,
                  )))));
      index++;
    }
    return widgets;
  }

  List<Widget> renderAssetList(
      {required List<Model> models, required AppRoutes route}) {
    List<Widget> widgets = [];
    for (var model in models) {
      widgets.add(Align(
        alignment: Alignment.centerLeft,
        child: model.trackpointNotes.isEmpty
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
                subtitle: model.trackpointNotes.isEmpty
                    ? null
                    : Text(model.trackpointNotes,
                        style: Theme.of(context).textTheme.bodySmall),
              ),
      ));
    }
    return widgets;
  }

  Widget renderItem(ModelTrackPoint model) {
    var divider = AppWidgets.divider();
    return ListTile(
      title: Column(children: [
        Text(
          '#${model.id}',
        ),
        Center(
            child: Text(
                '${util.formatDate(model.timeStart)} - ${util.formatDate(model.timeStart)}')),
        Center(child: Text(util.formatDuration(model.duration))),
        Align(
            alignment: Alignment.centerLeft,
            child: Text('OSM Addr: ${model.address}')),
        Column(
          children: [
            const Text('Location Alias'),
            ...renderAliasList(trackpoint: model, models: model.aliasModels)
          ],
        ),
        divider,
        Column(
          children: [
            const Text('Members'),
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
      ]),
      leading: IconButton(
          icon: const Icon(Icons.edit_note),
          onPressed: () {
            Navigator.pushNamed(context, AppRoutes.editTrackPoint.route,
                arguments: model.id);
          }),
    );
  }
}
