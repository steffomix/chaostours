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

//import 'package:chaostours/logger.dart';
import 'package:chaostours/conf/app_routes.dart';
import 'package:chaostours/view/app_widgets.dart';
import 'package:chaostours/model/model_user.dart';
import 'package:chaostours/model/model_user_group.dart';

class WidgetUserEdit extends StatefulWidget {
  const WidgetUserEdit({super.key});

  @override
  State<WidgetUserEdit> createState() => _WidgetUserEdit();
}

class _WidgetUserEdit extends State<WidgetUserEdit> {
  //static final Logger logger = Logger.logger<WidgetUserEdit>();

  ModelUser? _model;
  List<ModelUserGroup> _groups = [];

  void render() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<ModelUser?> loadUser(int id) async {
    var model = await ModelUser.byId(id);

    var ids = (await model?.groupIds()) ?? [];
    _groups = ids.isEmpty ? [] : await ModelUserGroup.byIdList(ids);
    return model;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ModelUser?>(
        initialData: _model,
        future:
            loadUser(ModalRoute.of(context)?.settings.arguments as int? ?? 0),
        builder: (context, snapshot) {
          return AppWidgets.checkSnapshot(context, snapshot,
                  build: (context, data) => _model = data) ??
              AppWidgets.scaffold(context,
                  body: renderBody(),
                  navBar: AppWidgets.navBarCreateItem(context, name: 'User',
                      onCreate: () async {
                    var count = (await ModelUser.count()) + 1;
                    var model = await ModelUser(title: '#$count').insert();
                    if (mounted) {
                      await Navigator.pushNamed(
                          context, AppRoutes.editUser.route,
                          arguments: model.id);
                      render();
                    }
                  }));
        });
  }

  Widget renderBody() {
    return ListView(children: [
      /// taskname
      Container(
          padding: const EdgeInsets.all(10),
          child: TextField(
            decoration: const InputDecoration(label: Text('User')),
            onChanged: ((value) {
              _model?.title = value;
              _model?.update();
            }),
            minLines: 1,
            maxLines: 5,
            controller: TextEditingController(text: _model?.title),
          )),

      /// notes
      Container(
          padding: const EdgeInsets.all(10),
          child: TextField(
            decoration: const InputDecoration(label: Text('Notes')),
            maxLines: null,
            minLines: 5,
            controller: TextEditingController(text: _model?.description),
            onChanged: (val) {
              _model?.description = val;
              _model?.update();
            },
          )),

      // groups
      Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: ElevatedButton(
              child: Column(children: [
                const Text('Groups', style: TextStyle(height: 2)),
                ..._groups.map(
                  (model) {
                    return ListTile(
                      title: Text(
                        model.title,
                      ),
                      subtitle: Text(model.description),
                    );
                  },
                ).toList()
              ]),
              onPressed: () {
                Navigator.pushNamed(
                        context, AppRoutes.listUserGroupsFromUser.route,
                        arguments: _model?.id)
                    .then(
                  (value) {
                    render();
                  },
                );
              })),

      AppWidgets.divider(),

      /// deleted
      ListTile(
          title: const Text('Active'),
          subtitle:
              const Text('Defines if this User is visible and used or not.'),
          leading: Checkbox(
            value: _model?.isActive ?? false,
            onChanged: (val) {
              _model?.isActive = val ?? false;
              _model?.update().then(
                (value) {
                  render();
                },
              );
            },
          ))
    ]);
  }
}
