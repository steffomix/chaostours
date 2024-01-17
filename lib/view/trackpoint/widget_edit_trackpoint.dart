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

import 'dart:math' as math;

///
import 'package:chaostours/conf/app_routes.dart';
import 'package:chaostours/model/model_task.dart';
import 'package:chaostours/model/model_trackpoint_task.dart';
import 'package:chaostours/model/model_trackpoint_user.dart';
import 'package:chaostours/model/model_user.dart';
import 'package:flutter/material.dart';
import 'package:chaostours/model/model_trackpoint.dart';
import 'package:chaostours/view/system/app_widgets.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/util.dart' as util;

///
/// CheckBox list
///
class WidgetEditTrackPoint extends StatefulWidget {
  const WidgetEditTrackPoint({super.key});

  @override
  State<StatefulWidget> createState() => _WidgetAddTasksState();
}

class _WidgetAddTasksState extends State<WidgetEditTrackPoint> {
  Logger logger = Logger.logger<WidgetEditTrackPoint>();

  late ModelTrackPoint _model;

  TextEditingController? _addressController;
  final _addressUndoController = UndoHistoryController();

  TextEditingController? _fullAddressController;
  final _fullAddressUndoController = UndoHistoryController();

  TextEditingController? _trackpointNotesController;

  Future<ModelTrackPoint> loadModel(int id) async {
    ModelTrackPoint? model = await ModelTrackPoint.byId(id);
    if (model == null) {
      throw 'Trackpoint #$id not found';
    }
    _model = model;
    return model;
  }

  void render() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    int id = ModalRoute.of(context)?.settings.arguments as int? ?? 0;
    return FutureBuilder(
      future: loadModel(id),
      builder: (context, snapshot) {
        return AppWidgets.checkSnapshot(context, snapshot) ??
            AppWidgets.scaffold(context,
                title: 'Edit Trackpoint', body: body());
      },
    );
  }

  Widget body() {
    return ListView(padding: const EdgeInsets.all(10), children: [
      dateTime(),
      duration(),
      AppWidgets.divider(),
      address(),
      AppWidgets.divider(),
      widgetAliases(),
      AppWidgets.divider(),
      widgetUsers(),
      widgetTasks(),
      AppWidgets.divider(),
      widgetTrackpointNotes()
    ]);
  }

  Widget address() {
    return Column(children: [
      Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: TextField(
            decoration: const InputDecoration(label: Text('Address')),
            onChanged: ((value) {
              _model.address = value;
              _model.update();
            }),
            minLines: 1,
            maxLines: 3,
            controller: _addressController ??=
                TextEditingController(text: _model.address),
            undoController: _addressUndoController,
          )),
      Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: TextField(
            decoration: const InputDecoration(label: Text('Address Details')),
            onChanged: ((value) {
              _model.fullAddress = value;
              _model.update();
            }),
            minLines: 1,
            maxLines: 3,
            controller: _fullAddressController ??=
                TextEditingController(text: _model.fullAddress),
            undoController: _fullAddressUndoController,
          )),
    ]);
  }

  Widget duration() {
    return Center(
        child: Text(
            util.formatDuration(_model.timeEnd.difference(_model.timeStart))));
  }

  Widget dateTime() {
    final firstDate = DateTime.now().subtract(const Duration(days: 365 * 100));
    final lastDate = DateTime.now().add(const Duration(days: 365 * 100));

    return Column(children: [
      Row(children: [
        ///
        /// date start
        Transform.rotate(
            angle: 0,
            child: const Icon(
              Icons.start,
            )),
        FilledButton(
          child: Text(util.formatDate(_model.timeStart)),
          onPressed: () async {
            DateTime? date = await showDatePicker(
                context: context,
                firstDate: firstDate,
                lastDate: lastDate,
                initialDate: _model.timeStart);
            if ((date != null)) {
              _model.timeStart = date.add(util.extractTime(_model.timeStart));
              await _model.update();
              render();
            }
          },
        ),

        ///
        /// time start
        Padding(
            padding: const EdgeInsets.only(left: 5),
            child: FilledButton(
              child: Text(util.formatTime(_model.timeStart)),
              onPressed: () async {
                TimeOfDay? time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(_model.timeStart));
                if ((time != null)) {
                  _model.timeStart = util
                      .removeTime(_model.timeStart)
                      .add(Duration(hours: time.hour, minutes: time.minute));
                  await _model.update();
                  render();
                }
              },
            ))
      ]),

      ///
      ///
      ///
      ///
      Row(children: [
        ///
        /// date end
        Transform.rotate(
            angle: math.pi,
            child: const Icon(
              Icons.start,
            )),
        FilledButton(
          child: Text(util.formatDate(_model.timeEnd)),
          onPressed: () async {
            DateTime? date = await showDatePicker(
                context: context,
                firstDate: firstDate,
                lastDate: lastDate,
                initialDate: _model.timeEnd);
            if ((date != null)) {
              _model.timeEnd = date.add(util.extractTime(_model.timeEnd));
              await _model.update();
              render();
            }
          },
        ),

        ///
        /// time end
        Padding(
            padding: const EdgeInsets.only(left: 5),
            child: FilledButton(
              child: Text(util.formatTime(_model.timeEnd)),
              onPressed: () async {
                TimeOfDay? time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(_model.timeEnd));
                if ((time != null)) {
                  _model.timeEnd = util
                      .removeTime(_model.timeEnd)
                      .add(Duration(hours: time.hour, minutes: time.minute));
                  await _model.update();
                  render();
                }
              },
            ))
      ]),
    ]);
  }

  /// aliasList
  ///
  ///
  ///
  Widget widgetAliases() {
    ///
    List<Widget> list = [];
    var i = 0;
    for (var model in _model.aliasModels) {
      i++;
      list.add(ListTile(
          leading: Icon(Icons.square, color: model.model.privacy.color),
          title: Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.editAlias.route,
                            arguments: model.model.id)
                        .then(
                      (value) {
                        render();
                      },
                    );
                  },
                  child: Text(
                    style: i > 1
                        ? null
                        : const TextStyle(
                            decoration: TextDecoration.underline,
                            fontWeight: FontWeight.bold),
                    '${model.distance(_model.gps)}m: ${util.cutString(model.model.title, 80)}',
                  )))));
    }
    return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: list);
  }

  Widget widgetUsers() {
    return ListTile(
      title: FilledButton(
        child: const Text('Members'),
        onPressed: () async {
          await dialogSelectUser();
          render();
        },
      ),
      subtitle: _model.userModels.isEmpty
          ? const Text('-')
          : Column(
              children: _model.userModels.map<Widget>(
                (model) {
                  return Align(
                      alignment: Alignment.centerLeft,
                      child: ListTile(
                          title: Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton(
                                child: Text(model.model.title),
                                onPressed: () {
                                  Navigator.pushNamed(
                                          context, AppRoutes.editUser.route,
                                          arguments: model.model.id)
                                      .then((value) {
                                    if (mounted) {
                                      render();
                                    }
                                  });
                                },
                              )),
                          subtitle: model.notes.isEmpty
                              ? null
                              : Text(model.notes,
                                  style: Theme.of(context).textTheme.bodySmall),
                          leading: IconButton(
                            icon: const Icon(Icons.note),
                            onPressed: () async {
                              await editUserNotes(model);
                              render();
                            },
                          )));
                },
              ).toList(),
            ),
    );
  }

  Future<void> editUserNotes(ModelTrackpointUser model) async {
    await AppWidgets.dialog(
        context: context,
        isDismissible: true,
        title: const Text('Notes'),
        contents: [
          Align(
              alignment: Alignment.centerLeft, child: Text(model.model.title)),
          TextField(
              controller: TextEditingController(text: model.notes),
              minLines: 3,
              maxLines: 8,
              onChanged: (text) async {
                await model.updateNotes(text);
                render();
              })
        ],
        buttons: [
          TextButton(
            child: const Text('OK'),
            onPressed: () async {
              if (mounted) {
                Navigator.pop(context);
              }
            },
          )
        ]);
  }

  Future<void> dialogSelectUser() async {
    if (await ModelUser.count() == 0 && mounted) {
      await AppWidgets.createUser(context);
      if (await ModelUser.count() == 0) {
        return;
      }
    }

    List<int> modelIds = _model.userModels.map<int>((e) => e.model.id).toList();
    List<ModelUser> selectables = await ModelUser.selectable();
    List<Widget> contents = (selectables).map<Widget>(
      (model) {
        return ListTile(
            title: Text(model.title),
            subtitle: Padding(
                padding: const EdgeInsets.only(left: 10),
                child: Text(util.cutString(model.description, 100))),
            trailing: AppWidgets.checkbox(
                value: modelIds.contains(model.id),
                onChanged: (bool? state) async {
                  var user = ModelTrackpointUser(
                      model: model, trackpointId: _model.id, notes: '');
                  await ((state ??= false)
                      ? _model.addUser(user)
                      : _model.removeUser(user));
                  render();
                }));
      },
    ).toList();
    if (mounted) {
      await AppWidgets.dialog(
          title: const Text('Select Users'),
          context: context,
          contents: contents,
          buttons: [
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                Navigator.pop(context);
                render();
              },
            )
          ],
          isDismissible: true);
    }
  }

  Widget widgetTasks() {
    return ListTile(
      title: FilledButton(
        child: const Text('Tasks'),
        onPressed: () async {
          await dialogSelectTask();
          render();
        },
      ),
      subtitle: _model.taskModels.isEmpty
          ? const Text('-')
          : Column(
              children: _model.taskModels.map<Widget>(
                (channelModel) {
                  return Align(
                      alignment: Alignment.centerLeft,
                      child: ListTile(
                          title: Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton(
                                child: Text(channelModel.model.title),
                                onPressed: () {
                                  Navigator.pushNamed(
                                          context, AppRoutes.editTask.route,
                                          arguments: channelModel.model.id)
                                      .then((value) {
                                    if (mounted) {
                                      render();
                                    }
                                  });
                                },
                              )),
                          subtitle: channelModel.notes.isEmpty
                              ? null
                              : Text(channelModel.notes,
                                  style: Theme.of(context).textTheme.bodySmall),
                          leading: IconButton(
                            icon: const Icon(Icons.note),
                            onPressed: () async {
                              await editTaskNotes(channelModel);
                              render();
                            },
                          )));
                },
              ).toList(),
            ),
    );
  }

  Future<void> editTaskNotes(ModelTrackpointTask model) async {
    await AppWidgets.dialog(
        context: context,
        isDismissible: true,
        title: const Text('Notes'),
        contents: [
          Align(
              alignment: Alignment.centerLeft, child: Text(model.model.title)),
          TextField(
              controller: TextEditingController(text: model.notes),
              minLines: 3,
              maxLines: 8,
              onChanged: (text) async {
                await model.updateNotes(text);
                render();
              })
        ],
        buttons: [
          TextButton(
            child: const Text('OK'),
            onPressed: () async {
              if (mounted) {
                Navigator.pop(context);
              }
            },
          )
        ]);
  }

  Future<void> dialogSelectTask() async {
    if (await ModelTask.count() == 0 && mounted) {
      await AppWidgets.createTask(context);
      if (await ModelTask.count() == 0) {
        return;
      }
    }

    List<int> modelIds = _model.taskModels.map<int>((e) => e.model.id).toList();
    List<ModelTask> selectables = await ModelTask.selectable();
    List<Widget> contents = (selectables).map<Widget>(
      (model) {
        return ListTile(
            title: Text(model.title),
            subtitle: Padding(
                padding: const EdgeInsets.only(left: 10),
                child: Text(util.cutString(model.description, 100))),
            trailing: AppWidgets.checkbox(
                value: modelIds.contains(model.id),
                onChanged: (bool? state) async {
                  var task = ModelTrackpointTask(
                      model: model, trackpointId: _model.id, notes: '');
                  await ((state ??= false)
                      ? _model.addTask(task)
                      : _model.removeTask(task));
                  render();
                }));
      },
    ).toList();
    if (mounted) {
      await AppWidgets.dialog(
          title: const Text('Select Tasks'),
          context: context,
          contents: contents,
          buttons: [
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                Navigator.pop(context);
              },
            )
          ],
          isDismissible: true);
    }
  }

  /// notes
  ///
  ///
  ///
  final _trackpointNotesUndoController = UndoHistoryController();
  Widget widgetTrackpointNotes() {
    _trackpointNotesController?.text = _model.notes;
    return ListTile(
        trailing: ListenableBuilder(
            listenable: _trackpointNotesUndoController,
            builder: (context, child) {
              return IconButton(
                icon: const Icon(Icons.undo),
                onPressed: _trackpointNotesUndoController.value.canUndo
                    ? () {
                        _trackpointNotesUndoController.undo();
                      }
                    : null,
              );
            }),
        title: TextField(
          decoration: const InputDecoration(label: Text('Trackpoint notes')),
          controller: _trackpointNotesController ??=
              TextEditingController(text: _model.notes),
          undoController: _trackpointNotesUndoController,
          minLines: 2,
          maxLines: 6,
          onChanged: (text) async {
            _model.notes = text;
            _model.update();
          },
        ));
  }
}
