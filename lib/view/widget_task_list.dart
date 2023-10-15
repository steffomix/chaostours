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
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:fluttertoast/fluttertoast.dart';

///
import 'package:chaostours/logger.dart';
import 'package:chaostours/screen.dart';
import 'package:chaostours/conf/app_routes.dart';
import 'package:chaostours/view/app_widgets.dart';
import 'package:chaostours/model/model_task.dart';

enum _DisplayMode {
  list,
  sort;
}

class WidgetTaskList extends StatefulWidget {
  const WidgetTaskList({super.key});

  @override
  State<WidgetTaskList> createState() => _WidgetTaskList();
}

class _WidgetTaskList extends State<WidgetTaskList> {
  // ignore: unused_field
  static final Logger logger = Logger.logger<WidgetTaskList>();

  final _showDeleted = ValueNotifier<bool>(false);
  final _textController = TextEditingController();
  _DisplayMode _displayMode = _DisplayMode.list;

  // height of seasrch field container
  final double _toolBarHeight = 70;

  // items per page
  static const int _limit = 30;

  final PagingController<int, ModelTask> _pagingController =
      PagingController(firstPageKey: 0);

  @override
  void initState() {
    _showDeleted.addListener(render);
    _pagingController.addPageRequestListener(_fetchPage);
    super.initState();
  }

  @override
  void dispose() {
    _showDeleted.dispose();
    _pagingController.dispose();
    super.dispose();
  }

  void render() {
    if (mounted) {
      setState(() {});
    }
  }

  void _fetchPage(int offset) async {
    var text = _textController.text;
    List<ModelTask> newItems = await (text.isEmpty
        ? ModelTask.select(limit: _limit, offset: offset)
        : ModelTask.search(text, limit: _limit, offset: offset));

    if (newItems.length < _limit) {
      _pagingController.appendLastPage(newItems);
    } else {
      _pagingController.appendPage(newItems, offset + newItems.length);
    }
  }

  Widget modelWidget(ModelTask model) {
    return ListBody(children: [
      ListTile(
          title: Text(model.title,
              style: TextStyle(
                  decoration: model.isActive
                      ? TextDecoration.none
                      : TextDecoration.lineThrough)),
          subtitle: Text(
            model.description,
            style: TextStyle(color: Theme.of(context).hintColor),
          ),
          trailing: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.editTasks.route,
                        arguments: model.id)
                    .then((_) {
                  _pagingController.refresh();
                  render();
                });
              }))
    ]);
  }

  Widget searchWidget() {
    return SizedBox(
        height: _toolBarHeight,
        width: Screen(context).width * 0.95,
        child: Align(
            alignment: Alignment.center,
            child: TextField(
              controller: _textController,
              minLines: 1,
              maxLines: 1,
              decoration: const InputDecoration(
                  icon: Icon(Icons.search, size: 30), border: InputBorder.none),
              onChanged: (value) {
                _pagingController.refresh();
                setState(() {});
              },
            )));
  }

  Widget sortWidget(List<ModelTask> models, int index) {
    var model = models[index];
    return ListTile(
        leading: IconButton(
            icon: const Icon(Icons.arrow_downward),
            onPressed: () {
              if (index < models.length - 1) {
                models[index + 1].sortOrder--;
                model.sortOrder++;
              }
              model.update().then((_) {
                models[index + 1].update().then(
                      (value) => setState(() {}),
                    );
              });
            }),
        trailing: IconButton(
          icon: const Icon(Icons.arrow_upward),
          onPressed: () {
            if (index > 0) {
              models[index - 1].sortOrder++;
              model.sortOrder--;
            }
            model.update().then((_) {
              models[index - 1].update().then(
                    (value) => setState(() {}),
                  );
            });
          },
        ),
        title: Text(model.title,
            style: !model.isActive
                ? const TextStyle(decoration: TextDecoration.lineThrough)
                : null),
        subtitle: Text(model.description));
  }

  @override
  Widget build(BuildContext context) {
    var body = CustomScrollView(slivers: <Widget>[
      SliverPersistentHeader(
          pinned: true,
          delegate: SliverHeader(
              widget: searchWidget(), //Text('Test'),
              toolBarHeight: _toolBarHeight,
              closedHeight: 0,
              openHeight: 0)),
      PagedSliverList<int, ModelTask>.separated(
        separatorBuilder: (BuildContext context, int i) => const Divider(),
        pagingController: _pagingController,
        builderDelegate: PagedChildBuilderDelegate<ModelTask>(
          itemBuilder: (context, model, index) {
            if (_displayMode == _DisplayMode.sort) {
              if (_pagingController.itemList == null) {
                return AppWidgets.loading('Waiting for Tasks...');
              }
              var list = _pagingController.itemList!;
              return sortWidget(list, index);
            } else {
              return modelWidget(model);
            }
          },
        ),
      ),
    ]);

    return AppWidgets.scaffold(context,
        body: body,
        appBar: AppBar(title: const Text('Aufgaben Liste')),
        navBar: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            items: [
              const BottomNavigationBarItem(
                  icon: Icon(Icons.add), label: 'Neu'),
              _displayMode == _DisplayMode.list
                  ? const BottomNavigationBarItem(
                      icon: Icon(Icons.sort), label: 'Sortieren')
                  : const BottomNavigationBarItem(
                      icon: Icon(Icons.list), label: 'Liste'),
              BottomNavigationBarItem(
                  icon: Icon(
                      _showDeleted.value || _displayMode == _DisplayMode.sort
                          ? Icons.visibility_off
                          : Icons.visibility),
                  label: _showDeleted.value || _displayMode == _DisplayMode.sort
                      ? 'Verb. Gel.'
                      : 'Zeige Gel.')
            ],
            onTap: (int id) {
              if (id == 0) {
                ModelTask.insert(ModelTask()).then(
                  (model) {
                    Fluttertoast.showToast(msg: 'Item #${model.id} created');
                    Navigator.pushNamed(context, AppRoutes.editTasks.route,
                            arguments: model.id)
                        .then(
                      (value) {
                        _pagingController.refresh();
                        render();
                      },
                    );
                  },
                );
              }
              if (id == 2) {
                _showDeleted.value = !_showDeleted.value;
                setState(() {});
              }
              if (id == 1) {
                _displayMode = _displayMode == _DisplayMode.list
                    ? _DisplayMode.sort
                    : _DisplayMode.list;
                setState(() {});
              }
            }));
  }
}
