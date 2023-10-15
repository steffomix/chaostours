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
import 'package:fluttertoast/fluttertoast.dart';

import 'package:chaostours/logger.dart';
import 'package:chaostours/view/app_widgets.dart';
import 'package:chaostours/conf/app_colors.dart';
import 'package:chaostours/model/model_task.dart';

class WidgetTaskEdit extends StatefulWidget {
  const WidgetTaskEdit({super.key});

  @override
  State<WidgetTaskEdit> createState() => _WidgetTaskEdit();
}

class _WidgetTaskEdit extends State<WidgetTaskEdit> {
  // ignore: unused_field
  static final Logger logger = Logger.logger<WidgetTaskEdit>();

  ValueNotifier<bool> modified = ValueNotifier<bool>(false);
  //TextEditingController nameController = TextEditingController();
  //TextEditingController notesController = TextEditingController();

  ModelTask? _model;
  int? _id;
  bool _initialized = false;

  @override
  void dispose() {
    super.dispose();
  }

  void modify() {
    modified.value = true;
  }

  @override
  Widget build(BuildContext context) {
    _id = ModalRoute.of(context)?.settings.arguments as int?;
    Widget? body;
    if (_id == null) {
      _model = ModelTask();
      _id = _model!.id;
      _initialized = true;
    } else if (!_initialized) {
      ModelTask.byId(_id!).then((ModelTask? model) {
        if (model == null && mounted) {
          Navigator.pop(context);
        }
        _model = model!;
        _id = model.id;
        _initialized = true;
        if (mounted) {
          setState(() => {});
        }
      });
      body = AppWidgets.loading('Loading task...');
    }
/*
    if (!_initialized) {
      if (_id > 0) {
        _model = ModelTask.getModel(_id).clone();
      } else {
        _model = ModelTask(title: '', notes: '', deleted: false);
      }
      _initialized = true;
    }
*/
    return AppWidgets.scaffold(context,
        appBar: AppBar(title: const Text('Aufgabe bearbeiten')),
        navBar: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            items: [
              // 0 alphabethic
              BottomNavigationBarItem(
                  icon: ValueListenableBuilder(
                      valueListenable: modified,
                      builder: ((context, value, child) {
                        return Icon(Icons.done,
                            size: 30,
                            color: modified.value == true
                                ? AppColors.green.color
                                : AppColors.white54.color);
                      })),
                  label: 'Speichern'),
              // 1 nearest
              const BottomNavigationBarItem(
                  icon: Icon(Icons.cancel), label: 'Abbrechen'),
            ],
            onTap: (int tapId) {
              var model = _model!;
              if (tapId == 0 && modified.value) {
                if (_id == 0) {
                  ModelTask.insert(model).then((id) {
                    if (model.title.trim().isEmpty) {
                      model.title = '#$id';
                    }
                    Navigator.pop(context);
                    Fluttertoast.showToast(msg: 'Task created');
                  });
                } else {
                  model.update().then((_) {
                    Navigator.pop(context);
                    Fluttertoast.showToast(msg: 'Task updated');
                  });
                }
              } else if (tapId == 1) {
                Navigator.pop(context);
              }
            }),
        body: body ?? renderBody());
  }

  Widget renderBody() {
    return ListView(children: [
      /// taskname
      Container(
          padding: const EdgeInsets.all(10),
          child: TextField(
            decoration: const InputDecoration(label: Text('Arbeit')),
            onChanged: ((value) {
              _model?.title = value;
              modify();
            }),
            maxLines: 1,
            minLines: 1,
            controller: TextEditingController(text: _model?.title),
          )),

      /// notes
      Container(
          padding: const EdgeInsets.all(10),
          child: TextField(
            decoration: const InputDecoration(label: Text('Notizen')),
            maxLines: null,
            minLines: 3,
            controller: TextEditingController(text: _model?.description),
            onChanged: (val) {
              _model?.description = val;
              modify();
            },
          )),

      /// deleted
      ListTile(
          title: const Text('Deaktiviert'),
          subtitle: const Text(
            'Definiert ob diese Arbeit sichtbar ist. '
            '\nBereits zugewiesene Arbeiten bleiben grundsätzlich sichtbar.',
            softWrap: true,
          ),
          leading: Checkbox(
            value: _model?.isActive,
            onChanged: (val) {
              _model?.isActive = val ?? false;
              modify();
              setState(() {});
            },
          ))
    ]);
  }
}
