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
import 'package:chaostours/view/app_widgets.dart';
import 'package:chaostours/model/model_task.dart';

class WidgetTaskEdit extends StatefulWidget {
  const WidgetTaskEdit({super.key});

  @override
  State<WidgetTaskEdit> createState() => _WidgetTaskEdit();
}

class _WidgetTaskEdit extends State<WidgetTaskEdit> {
  //static final Logger logger = Logger.logger<WidgetTaskEdit>();

  ModelTask? _model;
  int? _id;

  void render() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = ModalRoute.of(context)?.settings.arguments as int?;

    return FutureBuilder<ModelTask?>(
      future: ModelTask.byId(id ?? 0),
      builder: (context, snapshot) {
        return AppWidgets.checkSnapshot(snapshot) ??
            AppWidgets.scaffold(
              context,
              body: renderBody(snapshot.data!),
              appBar: AppBar(title: const Text('Edit Task')),
            );
      },
    );
  }

  Widget renderBody(ModelTask model) {
    _model = model;
    return ListView(children: [
      /// taskname
      Container(
          padding: const EdgeInsets.all(10),
          child: TextField(
            decoration: const InputDecoration(label: Text('Task')),
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

      /// deleted
      ListTile(
          title: const Text('Active'),
          subtitle:
              const Text('Defines if this Task is visible and used or not.'),
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
