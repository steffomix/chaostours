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

import 'package:chaostours/logger.dart';
import 'package:chaostours/util.dart';
import 'package:chaostours/conf/app_routes.dart';
import 'package:chaostours/conf/app_settings.dart';
import 'package:chaostours/view/app_widgets.dart';
import 'package:chaostours/conf/app_colors.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/screen.dart';
import 'package:chaostours/model/model_alias.dart';
import 'package:chaostours/model/model_trackpoint.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

class WidgetAliasTrackpoint extends StatefulWidget {
  const WidgetAliasTrackpoint({super.key});

  @override
  State<WidgetAliasTrackpoint> createState() => _WidgetAliasTrackpoint();
}

class _WidgetAliasTrackpoint extends State<WidgetAliasTrackpoint> {
  // ignore: unused_field
  static final Logger logger = Logger.logger<WidgetAliasTrackpoint>();

  final TextEditingController _searchTextController = TextEditingController();
  final PagingController<int, ModelTrackPoint> _pagingController =
      PagingController(firstPageKey: 0);
  final int _limit = 20;

  int? _aliasId;
  ModelAlias? _modelAlias;

  final double _toolBarHeight = 400;

  @override
  void initState() {
    _pagingController.addPageRequestListener(_fetchPage);
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _fetchPage(int offset) async {
    if (_modelAlias == null) {
      return;
    }
    final alias = _modelAlias!;
    final newItems =
        await ModelTrackPoint.byAlias(alias, offset: offset, limit: _limit);
    newItems.length < _limit
        ? _pagingController.appendLastPage(newItems)
        : _pagingController.appendPage(newItems, offset + newItems.length);
  }

  Widget mapWidget() {
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

  Widget searchWidget() {
    return TextField(
        controller: _searchTextController,
        minLines: 1,
        maxLines: 1,
        decoration: const InputDecoration(
            icon: Icon(Icons.search, size: 30), border: InputBorder.none),
        onChanged: (value) {
          setState(() {});
        });
  }

  /// alias header
  Widget aliasWidget() {
    var alias = _modelAlias!;
    return ListTile(
        title: Text(alias.title),
        subtitle: Text(alias.description),
        leading: Text('${alias.trackPointCount}x',
            style: TextStyle(
                backgroundColor: AppColors.aliasStatusColor(alias.visibility))),
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

  Widget trackPoint(ModelTrackPoint tp) {
    var date = '${AppSettings.weekDays[tp.timeStart.weekday]}. '
        '${tp.timeStart.day}.${tp.timeStart.month}.${tp.timeStart.year}';
    var dur = timeElapsed(tp.timeStart, tp.timeEnd, false);
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
    widgets.add(AppWidgets.divider());
    return Column(children: widgets);
  }

  Widget header() {
    return SizedBox(
        width: Screen(context).width * 0.95,
        height: _toolBarHeight,
        //padding: const EdgeInsets.only(bottom: 15),
        child: Column(children: [
          mapWidget(),
          searchWidget(),
          aliasWidget(),
          AppWidgets.divider()
        ]));
  }

  @override
  Widget build(BuildContext context) {
    if (_aliasId == null) {
      try {
        _aliasId = ModalRoute.of(context)!.settings.arguments as int;
        if (_aliasId! < 1) {
          throw "Invalid Alias ID #$_aliasId";
        }
      } catch (e, stk) {
        logger.error(e, stk);
        Future.delayed(
            const Duration(milliseconds: 10), () => Navigator.pop(context));
        return AppWidgets.empty;
      }
    }

    var body = FutureBuilder<ModelAlias?>(
      future: ModelAlias.byId(_aliasId!),
      builder: (context, snapshot) {
        var check = AppWidgets.checkSnapshot<ModelAlias?>(snapshot);
        if (check != null) {
          return check;
        }

        _modelAlias = snapshot.data!;
        return CustomScrollView(
          slivers: <Widget>[
            /// Pinned header
            SliverPersistentHeader(
                pinned: true,
                delegate: SliverHeader(
                    widget: header(),
                    toolBarHeight: _toolBarHeight,
                    closedHeight: 0,
                    openHeight: 0)),

            /// Items List
            PagedSliverList<int, ModelTrackPoint>.separated(
              separatorBuilder: (BuildContext context, int i) =>
                  const Divider(),
              pagingController: _pagingController,
              builderDelegate: PagedChildBuilderDelegate<ModelTrackPoint>(
                  itemBuilder: (context, model, index) => trackPoint(model)),
            ),
          ],
        );
      },
    );

    return AppWidgets.scaffold(context,
        body: body, appBar: AppBar(title: const Text('Haltepunkte')));
  }

/*
  Future<Widget?> body(BuildContext context) async {
    _modelAlias = await ModelAlias.getModel(_idAlias);

    _searchWidget = searchWidget();
    if (mounted) {
      _mapWidget = await mapWidget(context);

      if (_searchTextController.text.trim().isEmpty) {
        _trackPointModels = ModelTrackPoint.byAlias(_idAlias);
      } else {
        _trackPointModels.clear();

        /// pre-search idUser and idTask
        List<int> hasTask = [];
        List<int> hasUser = [];
        for (var item in ModelTask.getAll()) {
          if (item.title.toLowerCase().contains(_searchText)) {
            hasTask.add(item.id);
          }
        }
        for (var item in await ModelUser.getAll()) {
          if (item.title.toLowerCase().contains(_searchText)) {
            hasUser.add(item.id);
          }
        }

        /// begin search
        for (var item in ModelTrackPoint.byAlias(_idAlias)) {
          var found = false;
          if (item.notes.toLowerCase().contains(_searchText)) {
            _trackPointModels.add(item);
            continue;
          }
          for (var id in hasTask) {
            if (item.idTask.contains(id)) {
              _trackPointModels.add(item);
              found = true;
              break;
            }
          }
          if (!found) {
            for (var id in hasUser) {
              if (item.idUser.contains(id)) {
                _trackPointModels.add(item);
                break;
              }
            }
          }
        }
      }
      if (_trackPointModels.isEmpty) {
        return ListView(
          children: [
            _headerWidget ?? AppWidgets.empty,
            Container(
                padding: const EdgeInsets.all(30),
                child: const Center(
                    child: Text(
                        'Für diesen Ort wurden noch keine Haltepunkte aufgezeichnet.',
                        softWrap: true,
                        style: TextStyle(fontSize: 15))))
          ],
        );
      }
      return ListView.builder(
          itemCount: _trackPointModels.length + 1,
          itemBuilder: (context, id) {
            if (id == 0) {
              return _headerWidget ?? AppWidgets.empty;
            } else {
              return trackPoint(context, _trackPointModels[id - 1]);
            }
          });
    }
    return null;
  }
*/
}
