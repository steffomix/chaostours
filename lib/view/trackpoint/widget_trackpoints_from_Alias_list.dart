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

import 'package:chaostours/database/cache.dart';
import 'package:chaostours/view/app_base_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:chaostours/logger.dart';
import 'package:chaostours/util.dart';
import 'package:chaostours/conf/app_routes.dart';
import 'package:chaostours/conf/app_user_settings.dart';
import 'package:chaostours/view/app_widgets.dart';
import 'package:chaostours/conf/app_colors.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/screen.dart';
import 'package:chaostours/model/model_alias.dart';
import 'package:chaostours/model/model_trackpoint.dart';

class WidgetAliasTrackpoint extends BaseWidget {
  const WidgetAliasTrackpoint({super.key});

  @override
  State<WidgetAliasTrackpoint> createState() => _WidgetAliasTrackpoint();
}

class _WidgetAliasTrackpoint extends BaseWidgetState<WidgetAliasTrackpoint> {
  // ignore: unused_field
  static final Logger logger = Logger.logger<WidgetAliasTrackpoint>();

  final TextEditingController _searchTextController = TextEditingController();

  Weekdays weekdays = Weekdays.mondayFirst;
  ModelAlias? _modelAlias;
  final List<Widget> _loadedWidgets = [];

  @override
  Future<void> initialize(BuildContext context, Object? args) async {
    int id = args as int;
    _modelAlias = await ModelAlias.byId(id);
    weekdays =
        await Cache.appSettingWeekdays.load<Weekdays>(Weekdays.mondayFirst);
  }

  @override
  Future<void> resetLoader() async {
    await super.resetLoader();
    _loadedWidgets.clear();
    render();
  }

  @override
  Future<int> loadItems({required int offset, int limit = 20}) async {
    List<ModelTrackPoint> newItems = await _modelAlias?.trackpoints() ?? [];
    _loadedWidgets.addAll(
        intersperse(AppWidgets.divider(), newItems.map((e) => renderRow(e))));
    return newItems.length;
  }

  @override
  List<Widget> renderHeader(BoxConstraints constraints) {
    return [renderMapIcon(), renderAliasWidget(), renderSearchWidget()];
  }

  @override
  List<Widget> renderBody(BoxConstraints constraints) {
    return _loadedWidgets
        .map(
          (e) => SizedBox(width: constraints.maxWidth, child: e),
        )
        .toList();
  }

  @override
  Scaffold renderScaffold(Widget body) {
    return AppWidgets.scaffold(context, body: body);
  }

  ///
  ///
  ///
  ///

  Widget renderMapIcon() {
    if (_modelAlias == null) {
      return AppWidgets.empty;
    }
    return SizedBox(
        width: Screen(context).width,
        height: 50,
        child: IconButton(
            icon: const Icon(Icons.map),
            onPressed: () async {
              var gps = await GPS.gps();
              var lat = gps.lat;
              var lon = gps.lon;
              var lat1 = _modelAlias!.gps.lat;
              var lon1 = _modelAlias!.gps.lon;
              GPS.launchGoogleMaps(lat, lon, lat1, lon1);
            }));
  }

  Widget renderSearchWidget() {
    return AppWidgets.searchTile(
        context: context,
        textController: _searchTextController,
        onChange: (String text) {
          resetLoader();
        });
  }

  /// alias header
  Widget renderAliasWidget() {
    var alias = _modelAlias!;
    return ListTile(
        title: Text('#${alias.id} ${alias.title}'),
        subtitle: Text(alias.description),
        leading: Text('${alias.timesVisited}x',
            style: TextStyle(
                color: Colors.white, backgroundColor: alias.privacy.color)),
        trailing: IconButton(
          icon: Icon(Icons.edit, size: 30, color: AppColors.black.color),
          onPressed: () {
            Navigator.pushNamed(context, AppRoutes.editAlias.route,
                    arguments: alias.id)
                .then((_) {
              setState(() {});
            });
          },
        ));
  }

  Widget renderRow(ModelTrackPoint tp) {
    var date = '${weekdays.weekdays[tp.timeStart.weekday]}. '
        '${tp.timeStart.day}.${tp.timeStart.month}.${tp.timeStart.year}';
    var dur = formatDuration(tp.duration);
    var time =
        'von ${tp.timeStart.hour}:${tp.timeStart.minute} bis ${tp.timeEnd.hour}:${tp.timeEnd.minute}\n($dur)';
    Iterable<String> tasks = tp.taskModels.map((model) => model.title);
    Iterable<String> users = tp.userModels.map((model) => model.title);
    List<Widget> widgets = [
      ListTile(
          title: Text(date),
          subtitle: Text(time),
          trailing: IconButton(
            icon: const Icon(Icons.edit, size: 30),
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.editTrackPoint.route,
                      arguments: tp.id)
                  .then((_) {
                setState(() {});
              });
            },
          )),
    ];

    if (users.isNotEmpty) {
      widgets.add(ListTile(
        title: const Text('Personal'),
        subtitle: Text('- ${users.join('\n- ')}'),
      ));
    }

    if (tasks.isNotEmpty) {
      widgets.add(ListTile(
        title: const Text('Arbeiten'),
        subtitle: Text('- ${tasks.join('\n- ')}'),
      ));
    }

    if (tp.notes.trim().isNotEmpty) {
      widgets.add(ListTile(
          title: const Text('Notizen'),
          subtitle: Text(tp.notes),
          trailing: IconButton(
              icon: const Icon(Icons.copy),
              onPressed: () =>
                  Clipboard.setData(ClipboardData(text: tp.notes.trim())))));
    }
    return Column(children: widgets);
  }
}
