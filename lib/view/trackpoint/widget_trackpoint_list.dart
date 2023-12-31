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

import 'package:chaostours/conf/app_routes.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/model/model.dart';
import 'package:chaostours/model/model_alias.dart';
import 'package:chaostours/model/model_user.dart';
import 'package:flutter/material.dart';

//
import 'package:chaostours/view/app_base_widget.dart';
//import 'package:chaostours/logger.dart';
import 'package:chaostours/view/app_widgets.dart';
import 'package:chaostours/model/model_trackpoint.dart';
import 'package:chaostours/util.dart';

class WidgetTrackPoints extends BaseWidget {
  const WidgetTrackPoints({super.key});

  @override
  State<WidgetTrackPoints> createState() => _WidgetTrackPointsState();
}

class _WidgetTrackPointsState extends BaseWidgetState<WidgetTrackPoints> {
  //static final Logger logger = Logger.logger();
  TextEditingController tpSearch = TextEditingController();

  final _searchController = TextEditingController();
  final List<Widget> _loadedItems = [];

  int getLimit() => 20;

  @override
  Future<int> loadItems({int limit = 50, required int offset}) async {
    var items = await ModelTrackPoint.search(_searchController.text);
    if (_loadedItems.isNotEmpty) {
      _loadedItems.add(AppWidgets.divider());
    }
    _loadedItems.addAll(intersperse(
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
        Center(heightFactor: 2, child: Text('OSM Addr: ${model.address}')),
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
