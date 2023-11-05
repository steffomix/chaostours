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
import 'package:flutter/material.dart';

//
import 'package:chaostours/view/app_base_widget.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/view/app_widgets.dart';
import 'package:chaostours/model/model_trackpoint.dart';

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

  @override
  Future<int> loadItems({int limit = 50, required int offset}) async {
    var items = await ModelTrackPoint.search(_searchController.text);
    _loadedItems.addAll(items.map(
      (e) => renderItem(e),
    ));
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

  Widget renderItem(ModelTrackPoint model) {
    var alias = model.aliasModels.map((model) => model.title);
    var tasks = model.taskModels.map((model) => model.title);
    var users = model.userModels.map((model) => model.title);
    var divider = AppWidgets.divider();
    return ListTile(
      title: Column(children: [
        Center(heightFactor: 2, child: Text('OSM Addr: ${model.address}')),
        Center(heightFactor: 2, child: Text('Alias: - ${alias.join('\n- ')}')),
        Center(
            child: Text(AppWidgets.timeInfo(model.timeStart, model.timeEnd))),
        divider,
        Text(
            'Tasks:${tasks.isEmpty ? ' -' : '\n   - ${tasks.join('\n   - ')}'}'),
        divider,
        Text(
            'Users:${users.isEmpty ? ' -' : '\n   - ${users.join('\n   - ')}'}'),
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

/*
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ModelTrackPoint>>(
      future: ModelTrackPoint.search(_searchController.text),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return AppWidgets.loading(const Text(''));
        } else if (snapshot.hasError) {
          logger.error(
              'renderTrackPointSearchList ${snapshot.error ?? 'unknow error'}',
              StackTrace.current);
          return AppWidgets.loading(
              Text('FutureBuilder Error: ${snapshot.error ?? 'unknow error'}'));
        } else {
          if (snapshot.hasData) {
            var data = snapshot.data!;
            if (data.isEmpty) {
              return ListView(children: const [
                Text('\n\nNoch keine Haltepunkte erstellt')
              ]);
            } else {
              var searchWidget = ListTile(
                  subtitle: Text('Count: ${data.length}'),
                  title: AppWidgets.searchWidget(
                    context: context,
                    controller: _searchController,
                    onChange: (String value) {
                      if (value != _searchController.text) {
                        resetLoader();
                      }
                    },
                  ));
              return ListView.builder(
                  itemCount: data.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return searchWidget;
                    }
                    return AppWidgets.trackPointInfo(context, data[index - 1]);
                  });
            }
          } else {
            logger.warn('renderTrackPointSearchList FutureBuilder no data');
            return ListView(children: const [Text('\n\nNo Data')]);
          }
        }
      },
    );
  }
  */
}
