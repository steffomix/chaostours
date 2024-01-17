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

import 'dart:async';

import 'package:chaostours/model/model_trackpoint_task.dart';
import 'package:chaostours/model/model_trackpoint_user.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:fluttertoast/fluttertoast.dart';
//import 'package:visibility_detector/visibility_detector.dart';
import 'dart:math' as math;

import 'package:chaostours/address.dart';
import 'package:chaostours/channel/background_channel.dart';
import 'package:chaostours/conf/app_user_settings.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/model/model_task.dart';
import 'package:chaostours/model/model_user.dart';
import 'package:chaostours/screen.dart';
import 'package:chaostours/shared/shared_trackpoint_task.dart';
import 'package:chaostours/shared/shared_trackpoint_user.dart';
import 'package:chaostours/channel/data_channel.dart';
import 'package:chaostours/channel/tracking.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/conf/app_colors.dart';
import 'package:chaostours/conf/app_routes.dart';
import 'package:chaostours/event_manager.dart';
import 'package:chaostours/database/cache.dart';
import 'package:chaostours/util.dart' as util;
import 'package:chaostours/view/system/app_widgets.dart';

class WidgetTrackingPage extends StatefulWidget {
  const WidgetTrackingPage({super.key});

  @override
  State<WidgetTrackingPage> createState() => _WidgetTrackingPage();
}

class _WidgetTrackingPage extends State<WidgetTrackingPage> {
  static final Logger logger = Logger.logger<WidgetTrackingPage>();

  static int _bottomBarIndex = 0;

  final dataChannel = DataChannel();

  final divider = AppWidgets.divider();

  TextEditingController? _userNotesController;
  final addressIsLoading = ValueNotifier<bool>(false);

  final _listenableStatusTrigger = ValueNotifier<bool>(false);
  final _listenableTrackingStatus = ValueNotifier<bool>(false);
  final _listenableDate = ValueNotifier<bool>(false);
  final _listenableDuration = ValueNotifier<bool>(false);

  final _trackpointNotesUndoController = UndoHistoryController();

  bool _isUsersExpanded = false;
  bool _isTasksExpanded = false;

  // clock update
  Timer? _timer;

  void notify(ValueNotifier<bool> notifier) {
    notifier.value != notifier.value;
  }

  Future<void> render() async {
    if (mounted) {
      setState(() {});
    }
  }

  ///
  @override
  void initState() {
    () {
      var second = DateTime.now().second;
      _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
        if (mounted && DateTime.now().second != second) {
          second = DateTime.now().second;
          _listenableDate.value = !_listenableDate.value;
          _listenableDuration.value = !_listenableDuration.value;
        }
      });
    }();

    FlutterBackgroundService()
        .invoke(BackgroundChannelCommand.track.toString());
    EventManager.listen<DataChannel>(onTracking);
    EventManager.listen<EventOnRender>(onRender);
    super.initState();
  }

  ///
  @override
  void dispose() {
    _timer?.cancel();
    EventManager.remove<EventOnRender>(onRender);
    EventManager.remove<DataChannel>(onTracking);
    super.dispose();
  }

  ///
  void onTracking(DataChannel dataChannel) {
    if (mounted) {
      setState(() {});
    }
  }

  ///
  void onRender(EventOnRender _) {
    if (mounted) {
      setState(() {});
    }
  }

  ///
  @override
  Widget build(BuildContext context) {
    Widget widget = ListView(children: [
      initialized(),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        statusTriggerIcon(),
        widgetTrackingStatus(),
        const Icon(Icons.stop, color: Colors.transparent),
      ]),
      Center(child: widgetDate()),
      Center(child: widgetDuration()),
      skipRecord(),
      //AppWidgets.divider(),
      widgetAddress(),
      ListTile(
          title: Column(children: [
        widgetAliases(),
        AppWidgets.divider(),
        widgetSelectedTasks(),
        widgetSelectedUsers(),
        AppWidgets.divider(),
        widgetTrackpointNotes(),
        AppWidgets.divider(),
        Text('', style: Theme.of(context).textTheme.bodySmall)
      ]))
    ]);
    return AppWidgets.scaffold(context,
        body: widget,
        navBar: bottomNavBar(context),
        appBar: AppBar(title: const Text('Live Tracking')));
  }

  Widget initialized() {
    return dataChannel.initalized
        ? const SizedBox.shrink()
        : Text('Waiting for first GPS...',
            style: TextStyle(
                backgroundColor: AppColors.warning.color,
                color: AppColors.black.color));
  }

  Widget statusTriggerIcon() {
    double? size = Theme.of(context).iconTheme.size;
    if (size != null) {
      size *= 3;
    }
    Screen screen = Screen(context);
    size = math.min(screen.width, screen.height) / 15;
    return ListenableBuilder(
      listenable: _listenableStatusTrigger,
      builder: (context, child) {
        return dataChannel.trackingStatus == TrackingStatus.standing
            ? IconButton(
                icon: Icon(
                    dataChannel.trackingStatusTrigger == TrackingStatus.none
                        ? Icons.flag
                        : Icons.hourglass_top,
                    size: 50),
                onPressed: () async {
                  ///start

                  AppWidgets.dialog(
                      context: context,
                      title: const Text('Start?'),
                      contents: [
                        const Text(
                            'This action will trigger Start and save a trackpoint of this location. '
                            'Usualy the Status moves back to Standing with the next interval.')
                      ],
                      buttons: [
                        TextButton(
                          child: const Text('Yes'),
                          onPressed: () async {
                            Navigator.pop(context);
                            FlutterBackgroundService().invoke(
                                BackgroundChannelCommand.reloadUserSettings
                                    .toString());
                            if (dataChannel.trackingStatusTrigger !=
                                TrackingStatus.moving) {
                              Fluttertoast.showToast(msg: 'Start sheduled');
                            }
                            dataChannel.trackingStatusTrigger = await Cache
                                .trackingStatusTriggered
                                .save<TrackingStatus>(TrackingStatus.moving);
                            notify(_listenableStatusTrigger);
                          },
                        ),
                        TextButton(
                          child: const Text('Cancel'),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                        )
                      ]);

                  ///end
                })
            : IconButton(
                icon: Icon(
                    dataChannel.trackingStatusTrigger == TrackingStatus.none
                        ? Icons.drive_eta
                        : Icons.hourglass_top),
                onPressed: () async {
                  AppWidgets.dialog(
                      context: context,
                      title: const Text('Stop?'),
                      contents: [
                        const Text(
                            'This action will trigger Stop and reset all measurement points to this current location.')
                      ],
                      buttons: [
                        TextButton(
                          child: const Text('Yes'),
                          onPressed: () async {
                            Navigator.pop(context);
                            FlutterBackgroundService().invoke(
                                BackgroundChannelCommand.reloadUserSettings
                                    .toString());
                            if (dataChannel.trackingStatusTrigger !=
                                TrackingStatus.standing) {
                              Fluttertoast.showToast(msg: 'Stop sheduled');
                            }
                            dataChannel.trackingStatusTrigger = await Cache
                                .trackingStatusTriggered
                                .save<TrackingStatus>(TrackingStatus.moving);
                            notify(_listenableStatusTrigger);
                          },
                        ),
                        TextButton(
                          child: const Text('Cancel'),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                        )
                      ]);
                });
      },
    );
  }

  Widget skipRecord() {
    return ListTile(
        leading: AppWidgets.checkbox(
            value: dataChannel.skipTracking,
            onChanged: (state) async {
              dataChannel.skipTracking = await Cache
                  .backgroundTrackPointSkipRecordOnce
                  .save<bool>(state ?? false);
            }),
        title: const Text('Skip Record'),
        trailing: IconButton(
          icon: const Icon(Icons.question_mark),
          onPressed: () {
            AppWidgets.dialog(
                context: context,
                title: const Text('Skip Record'),
                contents: [
                  const Text(
                      'Pause record and publish trackpoints until you have started moving from a known location alias.')
                ],
                buttons: [
                  FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'))
                ]);
          },
        ));
  }

  Widget widgetTrackingStatus() {
    return Center(
        child: ListenableBuilder(
            listenable: _listenableTrackingStatus,
            builder: (context, child) {
              return Text('${dataChannel.trackingStatus.name.toUpperCase()}\n',
                  style: Theme.of(context).textTheme.titleLarge);
            }));
  }

  Widget widgetDate() {
    return ListenableBuilder(
        listenable: _listenableDate,
        builder: (context, child) {
          return Text(util.formatDateTime(DateTime.now()));
        });
  }

  Widget widgetDuration() {
    return Center(
        child: ListenableBuilder(
            listenable: _listenableDuration,
            builder: (context, child) {
              return Text(util.formatDuration(dataChannel.duration));
            }));
  }

  /// address
  ///
  ///
  ///
  Widget widgetAddress() {
    return ListTile(
        trailing: IconButton(
          icon: ListenableBuilder(
              listenable: addressIsLoading,
              builder: (context, child) {
                return addressIsLoading.value
                    ? const CircularProgressIndicator()
                    : const Icon(Icons.restore);
              }),
          onPressed: () async {
            if (addressIsLoading.value) {
              return;
            }
            addressIsLoading.value = true;
            try {
              final GPS gps = await GPS.gps();
              final Address address =
                  await Address(gps).lookup(OsmLookupConditions.onUserRequest);

              dataChannel.address =
                  await Cache.addressMostRecent.save<String>(address.address);
              dataChannel.fullAddress = await Cache.addressFullMostRecent
                  .save<String>(address.addressDetails);
              setState(() {});
              if (mounted) {
                AppWidgets.dialog(
                    isDismissible: true,
                    context: context,
                    contents: [
                      ListTile(
                          title: const Text('Address'),
                          subtitle: Text(address.address),
                          trailing: IconButton(
                            icon: const Icon(Icons.copy),
                            onPressed: () {
                              Clipboard.setData(
                                  ClipboardData(text: address.address));
                            },
                          )),
                      ListTile(
                          title: const Text('Address Details'),
                          subtitle: Text(address.addressDetails),
                          trailing: IconButton(
                            icon: const Icon(Icons.copy),
                            onPressed: () {
                              Clipboard.setData(
                                  ClipboardData(text: address.addressDetails));
                            },
                          )),
                    ],
                    buttons: [
                      TextButton(
                        child: const Text('OK'),
                        onPressed: () => Navigator.pop(context),
                      )
                    ]);
              }
              addressIsLoading.value = false;
            } catch (e, stk) {
              logger.error('update address: $e', stk);
            }
          },
        ),
        title: Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              child: Text(util.cutString(dataChannel.address, 80)),
              onPressed: () {
                AppWidgets.dialog(
                    isDismissible: true,
                    context: context,
                    contents: [
                      ListTile(
                          title: Text(dataChannel.address),
                          trailing: IconButton(
                            icon: const Icon(Icons.copy),
                            onPressed: () {
                              Clipboard.setData(
                                  ClipboardData(text: dataChannel.address));
                            },
                          )),
                      AppWidgets.divider(),
                      ListTile(
                          title: Text(dataChannel.fullAddress),
                          trailing: IconButton(
                            icon: const Icon(Icons.copy),
                            onPressed: () {
                              Clipboard.setData(
                                  ClipboardData(text: dataChannel.fullAddress));
                            },
                          ))
                    ],
                    buttons: [
                      TextButton(
                        child: const Text('OK'),
                        onPressed: () => Navigator.pop(context),
                      )
                    ]);
              },
            )));
  }

  /// aliasList
  ///
  ///
  ///
  Widget widgetAliases() {
    ///
    List<Widget> list = [];
    var i = 0;
    for (var model in dataChannel.aliasList) {
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
                    '${dataChannel.gps == null ? '...' : model.distance(dataChannel.gps!)}m: ${util.cutString(model.model.title, 80)}',
                  )))));
    }
    return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: list);
  }

  /// users
  ///
  ///
  ///
  Widget widgetSelectedUsers() {
    dataChannel.sortUser();
    return _isUsersExpanded
        ? widgetselectedUsersExpanded()
        : widgetSelectedUsersCollapsed();
  }

  Widget widgetSelectedUsersCollapsed() {
    Color? color =
        dataChannel.userList.isEmpty ? const Color.fromARGB(0, 0, 0, 0) : null;
    return ListTile(
      trailing: IconButton(
        icon: _isUsersExpanded
            ? Icon(Icons.cancel_rounded, color: color)
            : Icon(Icons.menu_open, color: color),
        onPressed: () async {
          _isUsersExpanded = !_isUsersExpanded;
          setState(() {});
        },
      ),
      title: FilledButton(
        child: const Text('Members'),
        onPressed: () async {
          await dialogSelectUser();
          await dataChannel.updateAssets();
          if (mounted) {
            setState(() {});
          }
        },
      ),
      subtitle: dataChannel.userList.isEmpty
          ? const Text('-')
          : Column(
              children: dataChannel.userList.map<Widget>(
              (channelModel) {
                return Align(
                    alignment: Alignment.centerLeft,
                    child: Text(channelModel.model.title));
              },
            ).toList()),
    );
  }

  Widget widgetselectedUsersExpanded() {
    Color? color =
        dataChannel.userList.isEmpty ? const Color.fromARGB(0, 0, 0, 0) : null;
    return ListTile(
      trailing: IconButton(
        icon: _isUsersExpanded
            ? Icon(Icons.cancel_rounded, color: color)
            : Icon(Icons.menu_open, color: color),
        onPressed: () async {
          _isUsersExpanded = !_isUsersExpanded;
          setState(() {});
        },
      ),
      title: FilledButton(
        child: const Text('Members'),
        onPressed: () async {
          await dialogSelectUser();
          await dataChannel.updateAssets();
          if (mounted) {
            setState(() {});
          }
        },
      ),
      subtitle: dataChannel.userList.isEmpty
          ? const Text('-')
          : Column(
              children: dataChannel.userList.map<Widget>(
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
                                          context, AppRoutes.editUser.route,
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
                              await editUserNotes(channelModel);
                              render();
                            },
                          )));
                },
              ).toList(),
            ),
    );
  }

  Future<void> editUserNotes(ModelTrackpointUser model) async {
    final controller = TextEditingController(text: model.notes);
    await AppWidgets.dialog(
        context: context,
        isDismissible: true,
        title: const Text('Notes'),
        contents: [
          Align(
              alignment: Alignment.centerLeft, child: Text(model.model.title)),
          TextField(
              controller: controller,
              minLines: 3,
              maxLines: 8,
              onChanged: (text) async {})
        ],
        buttons: [
          TextButton(
            child: const Text('OK'),
            onPressed: () async {
              await SharedTrackpointUser.addOrUpdate(model.model,
                  notes: controller.text);
              await dataChannel.updateAssets();
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

    List<int> modelIds =
        dataChannel.userList.map<int>((e) => e.model.id).toList();
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
                  await ((state ??= false)
                      ? SharedTrackpointUser.addOrUpdate(model)
                      : SharedTrackpointUser.remove(model));
                  await dataChannel.updateUserList();
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
              },
            )
          ],
          isDismissible: true);
    }
  }

  /// tasks
  ///
  ///
  ///
  Widget widgetSelectedTasks() {
    dataChannel.sortTask();
    return _isTasksExpanded
        ? widgetselectedTasksExpanded()
        : widgetselectedTasksCollapsed();
  }

  Widget widgetselectedTasksCollapsed() {
    Color? color =
        dataChannel.taskList.isEmpty ? const Color.fromARGB(0, 0, 0, 0) : null;
    return ListTile(
      trailing: IconButton(
        icon: _isTasksExpanded
            ? Icon(Icons.cancel_rounded, color: color)
            : Icon(Icons.menu_open, color: color),
        onPressed: () async {
          _isTasksExpanded =
              dataChannel.taskList.isEmpty ? false : !_isTasksExpanded;
          setState(() {});
        },
      ),
      title: FilledButton(
        child: const Text('Tasks'),
        onPressed: () async {
          await dialogSelectTask();
          await dataChannel.updateAssets();
          if (mounted) {
            setState(() {});
          }
        },
      ),
      subtitle: dataChannel.taskList.isEmpty
          ? const Text('-')
          : Column(
              children: dataChannel.taskList.map<Widget>(
              (channelModel) {
                return Align(
                    alignment: Alignment.centerLeft,
                    child: Text(channelModel.model.title));
              },
            ).toList()),
    );
  }

  Widget widgetselectedTasksExpanded() {
    Color? color =
        dataChannel.taskList.isEmpty ? const Color.fromARGB(0, 0, 0, 0) : null;
    return ListTile(
      trailing: IconButton(
        icon: _isTasksExpanded
            ? Icon(Icons.cancel_rounded, color: color)
            : Icon(Icons.menu_open, color: color),
        onPressed: () async {
          _isTasksExpanded = !_isTasksExpanded;
          setState(() {});
        },
      ),
      title: FilledButton(
        child: const Text('Tasks'),
        onPressed: () async {
          await dialogSelectTask();
          await dataChannel.updateAssets();
          if (mounted) {
            setState(() {});
          }
        },
      ),
      subtitle: dataChannel.taskList.isEmpty
          ? const Text('-')
          : Column(
              children: dataChannel.taskList.map<Widget>(
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
    final controller = TextEditingController(text: model.notes);
    await AppWidgets.dialog(
        context: context,
        isDismissible: true,
        title: const Text('Notes'),
        contents: [
          Align(
              alignment: Alignment.centerLeft, child: Text(model.model.title)),
          TextField(
            controller: controller,
            minLines: 3,
            maxLines: 8,
          )
        ],
        buttons: [
          TextButton(
            child: const Text('OK'),
            onPressed: () async {
              await SharedTrackpointTask.addOrUpdate(model.model,
                  notes: controller.text);
              await dataChannel.updateAssets();
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

    List<int> modelIds =
        dataChannel.taskList.map<int>((e) => e.model.id).toList();
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
                  await ((state ??= false)
                      ? SharedTrackpointTask.addOrUpdate(model)
                      : SharedTrackpointTask.remove(model));
                  await dataChannel.updateTaskList();
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
  Widget widgetTrackpointNotes() {
    _userNotesController?.text = dataChannel.notes;
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
          controller: _userNotesController ??=
              TextEditingController(text: dataChannel.notes),
          undoController: _trackpointNotesUndoController,
          minLines: 2,
          maxLines: 6,
          decoration: const InputDecoration(hintText: 'Notes'),
          onChanged: (text) async {
            await dataChannel.setTrackpointNotes(text);
            if (mounted) {
              //notify(_listenableUndoUserNotes);
              //setState(() {});
            }
          },
        ));
  }

  ///
  BottomNavigationBar bottomNavBar(BuildContext context) {
    return BottomNavigationBar(
        currentIndex: _bottomBarIndex,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.search), label: 'Trackpoints'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
        ],
        onTap: (int id) async {
          switch (id) {
            case 0: // 1.
              Navigator.pushNamed(context, AppRoutes.listTrackpoints.route)
                  .then(
                (value) => render(),
              );
              break;
            case 1: // 2.
              Navigator.pushNamed(context, AppRoutes.osm.route).then(
                (value) => render(),
              );
              break;
            default: //3.
          }
          _bottomBarIndex = id;
          render();
        });
  }
}
