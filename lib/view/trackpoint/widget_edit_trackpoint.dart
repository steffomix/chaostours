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

import 'package:chaostours/channel/data_channel.dart';
import 'package:chaostours/location.dart';
import 'package:chaostours/shared/shared_trackpoint_user.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
//
import 'package:chaostours/conf/app_routes.dart';
import 'package:chaostours/conf/app_colors.dart';
import 'package:chaostours/model/model_user.dart';
import 'package:chaostours/model/model_task.dart';
import 'package:chaostours/model/model_alias.dart';
import 'package:chaostours/model/model_trackpoint.dart';
import 'package:chaostours/view/app_widgets.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/screen.dart';
import 'package:chaostours/gps.dart';
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
  late Location _location;

  TextEditingController? _addressController;
  final _addressUndoController = UndoHistoryController();

  TextEditingController? _fullAddressController;
  final _fullAddressUndoController = UndoHistoryController();

  Future<ModelTrackPoint> loadModel(int id) async {
    ModelTrackPoint? model = await ModelTrackPoint.byId(id);
    if (model == null) {
      throw 'Trackpoint #$id not found';
    }
    _location = await Location.location(model.gps);
    return model;
  }

  void render() {
    if (mounted) {
      render();
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
    return ListView(padding: const EdgeInsets.all(5), children: []);
  }

  Widget address() {
    return Column(children: [
      TextField(
        decoration: const InputDecoration(label: Text('Address')),
        onChanged: ((value) {
          _model.address = value;
          _model.update();
        }),
        minLines: 1,
        maxLines: 3,
        controller: _addressController,
        undoController: _addressUndoController,
      ),
      TextField(
        decoration: const InputDecoration(label: Text('Address Details')),
        onChanged: ((value) {
          _model.fullAddress = value;
          _model.update();
        }),
        minLines: 1,
        maxLines: 3,
        controller: _fullAddressController,
        undoController: _fullAddressUndoController,
      ),
    ]);
  }

  Widget dateTime() {
    final firstDate = DateTime.now().subtract(const Duration(days: 365 * 10));
    final lastDate = DateTime.now().subtract(const Duration(days: 365 * 10));

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
        FilledButton(
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
        )
      ]),

      ///
      ///
      ///
      ///
      Row(children: [
        ///
        /// date end
        Transform.rotate(
            angle: 0,
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
        FilledButton(
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
        )
      ]),
    ]);
  }

  Widget widgetAliases() {
    ///
    List<Widget> list = [];
    var i = 0;
    for (var model in _model.aliasModels) {
      i++;
      list.add(ListTile(
          leading: Icon(Icons.square, color: model.privacy.color),
          title: Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.editAlias.route,
                            arguments: model.id)
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
                    util.cutString(model.title, 80),
                  )))));
    }
    return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: list);
  }

  Widget widgetselectedUsers() {
    final models = _model.userTrackpoints;
    Color? color = models.isEmpty ? const Color.fromARGB(0, 0, 0, 0) : null;
    return ListTile(
      title: FilledButton(
        child: const Text('Members'),
        onPressed: () async {
          await dialogSelectUser();
          render();
        },
      ),
      subtitle: models.isEmpty
          ? const Text('-')
          : Column(
              children: models.map<Widget>(
                (model) {
                  return Align(
                      alignment: Alignment.centerLeft,
                      child: ListTile(
                          title: Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton(
                                child: Text(model.notes),
                                onPressed: () {
                                  Navigator.pushNamed(
                                          context, AppRoutes.editUser.route,
                                          arguments: model.id)
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

  Future<void> dialogSelectUser() async {
    if (await ModelUser.count() == 0 && mounted) {
      await AppWidgets.createUser(context);
      if (await ModelUser.count() == 0) {
        return;
      }
    }

    List<int> modelIds = _model.userModels.map<int>((e) => e.id).toList();
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
                  throw 'not implemented: add or remove user';
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
              },
            )
          ],
          isDismissible: true);
    }
  }

  Future<void> editUserNotes(ChannelUser channelModel) async {
    await AppWidgets.dialog(
        context: context,
        isDismissible: true,
        title: const Text('Notes'),
        contents: [
          Align(
              alignment: Alignment.centerLeft,
              child: Text(channelModel.model.title)),
          TextField(
              controller:
                  TextEditingController(text: channelModel.shared.notes),
              minLines: 3,
              maxLines: 8,
              onChanged: (text) async {
                SharedTrackpointUser.addOrUpdate(channelModel.model,
                    notes: text);
              })
        ],
        buttons: [
          TextButton(
            child: const Text('OK'),
            onPressed: () async {
              await dataChannel.updateAssets();
              if (mounted) {
                Navigator.pop(context);
              }
            },
          )
        ]);
  }
}
