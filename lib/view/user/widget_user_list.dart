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

import 'package:chaostours/logger.dart';
import 'package:chaostours/view/app_widgets.dart';
import 'package:chaostours/view/app_base_widget.dart';
import 'package:chaostours/conf/app_routes.dart';
import 'package:chaostours/model/model_User.dart';

class WidgetUserList extends BaseWidget {
  const WidgetUserList({super.key});

  @override
  State<WidgetUserList> createState() => _WidgetUserList();
}

class _WidgetUserList extends BaseWidgetState<WidgetUserList> {
  // ignore: unused_field
  static final Logger logger = Logger.logger<WidgetUserList>();

  bool _showActivated = true;
  final _textController = TextEditingController();

  final List<Widget> _loadedItems = [];

  @override
  Future<void> initialize(BuildContext context, Object? args) async {}

  @override
  Future<void> resetLoader() async {
    await super.resetLoader();
    _loadedItems.clear();
    render();
  }

  @override
  Future<int> loadItems({required int offset, int limit = 20}) async {
    List<ModelUser> newItems = await ModelUser.select(
        limit: limit,
        offset: offset,
        activated: _showActivated,
        search: _textController.text);

    _loadedItems.addAll(newItems.map((e) => renderListItem(e)).toList());
    return newItems.length;
  }

  @override
  List<Widget> renderBody(BoxConstraints constraints) {
    return _loadedItems
        .map((e) => SizedBox(width: constraints.maxWidth, child: e))
        .toList();
  }

  @override
  List<Widget> renderHeader(BoxConstraints constraints) {
    return [
      AppWidgets.searchTile(
          context: context,
          textController: _textController,
          onChange: (search) {
            resetLoader();
          })
    ];
  }

  @override
  Scaffold renderScaffold(Widget body) {
    return AppWidgets.scaffold(context,
        body: body, title: 'Users', navBar: navBar());
  }

  BottomNavigationBar navBar() {
    return BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: [
          const BottomNavigationBarItem(
              icon: Icon(Icons.add), label: 'Create new User'),
          _showActivated
              ? const BottomNavigationBarItem(
                  icon: Icon(Icons.delete), label: 'Show Deleted')
              : const BottomNavigationBarItem(
                  icon: Icon(Icons.visibility), label: 'Show Active'),
          const BottomNavigationBarItem(
              icon: Icon(Icons.cancel), label: 'Cancel'),
        ],
        onTap: (int id) async {
          if (id == 0) {
            AppWidgets.dialog(context: context, contents: [
              const Text('Create new User?')
            ], buttons: [
              TextButton(
                child: const Text('Cancel'),
                onPressed: () => Navigator.pop(context),
              ),
              TextButton(
                child: const Text('Yes'),
                onPressed: () async {
                  var count = await ModelUser.count();
                  var model =
                      await ModelUser.insert(ModelUser(title: '#${count + 1}'));
                  if (mounted) {
                    Navigator.pushNamed(context, AppRoutes.editUser.route,
                            arguments: model.id)
                        .then((value) {
                      Navigator.pop(context);
                      resetLoader();
                    });
                  }
                },
              )
            ]);
          } else if (id == 1) {
            _showActivated = !_showActivated;
            resetLoader();
          } else {
            Navigator.pop(context);
          }
        });
  }

  Widget renderListItem(ModelUser model) {
    return ListTile(
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
            onPressed: () async {
              await Navigator.pushNamed(context, AppRoutes.editUser.route,
                  arguments: model.id);
              resetLoader();
            }));
  }
}
