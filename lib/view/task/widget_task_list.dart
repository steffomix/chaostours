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

import 'package:chaostours/view/app_base_widget.dart';
import 'package:flutter/material.dart';

///
import 'package:chaostours/logger.dart';
import 'package:chaostours/screen.dart';
import 'package:chaostours/conf/app_routes.dart';
import 'package:chaostours/model/model_task.dart';

enum _DisplayMode {
  list,
  sort;
}

class WidgetTaskList extends BaseWidget {
  const WidgetTaskList({super.key});

  @override
  State<WidgetTaskList> createState() => _WidgetTaskList();
}

class _WidgetTaskList extends BaseWidgetState<WidgetTaskList> {
  // ignore: unused_field
  static final Logger logger = Logger.logger<WidgetTaskList>();

  final _selectDeleted = ValueNotifier<bool>(false);
  final _textController = TextEditingController();
  _DisplayMode _displayMode = _DisplayMode.list;

  // height of seasrch field container
  final double _toolBarHeight = 70;

  // items per page
  static const int _limit = 30;

  @override
  void initState() {
    _selectDeleted.addListener(render);
    // ModelTask.resetSortOrder();
    super.initState();
  }

  @override
  void dispose() {
    _selectDeleted.dispose();
    super.dispose();
  }

  void _fetchPage(int offset) async {
    var text = _textController.text;
    List<ModelTask> newItems =
        await (text.isEmpty || _displayMode == _DisplayMode.sort
            ? ModelTask.select(
                limit: _limit,
                offset: offset,
                selectDeleted:
                    _selectDeleted.value || _displayMode == _DisplayMode.sort,
                useSortOrder: _displayMode == _DisplayMode.sort)
            : ModelTask.search(text,
                limit: _limit,
                offset: offset,
                selectDeleted: _selectDeleted.value));

    if (newItems.length < _limit) {
      // _pagingController.appendLastPage(newItems);
    } else {
      // _pagingController.appendPage(newItems, offset + newItems.length);
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
                  // _pagingController.refresh();
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
                // _pagingController.refresh();
                render();
              },
            )));
  }

  Widget sortWidget(List<ModelTask> models, int index) {
    var model = models[index];
    return ListTile(
        leading: IconButton(
            icon: const Icon(Icons.arrow_downward),
            onPressed: () async {
              if (index < models.length - 1) {
                models[index + 1].sortOrder--;
                model.sortOrder++;
                await model.update();
                await models[index + 1].update();
                // _pagingController.refresh();
                render();
              }
            }),
        trailing: IconButton(
          icon: const Icon(Icons.arrow_upward),
          onPressed: () async {
            if (index > 0) {
              models[index - 1].sortOrder++;
              model.sortOrder--;
              await model.update();
              await models[index - 1].update();
              // _pagingController.refresh();
              render();
            }
          },
        ),
        title: Text(model.title,
            style: !model.isActive
                ? const TextStyle(decoration: TextDecoration.lineThrough)
                : null),
        subtitle: Text(model.description));
  }
}
