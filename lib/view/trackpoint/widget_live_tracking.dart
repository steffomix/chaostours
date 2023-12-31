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
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:fluttertoast/fluttertoast.dart';
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
//import 'package:visibility_detector/visibility_detector.dart';

import 'package:chaostours/channel/data_channel.dart';
import 'package:chaostours/channel/tracking.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/conf/app_colors.dart';
import 'package:chaostours/conf/app_routes.dart';
import 'package:chaostours/event_manager.dart';
import 'package:chaostours/database/cache.dart';
import 'package:chaostours/util.dart' as util;
import 'package:chaostours/view/app_widgets.dart';

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
  final _listenableUndoUserNotes = ValueNotifier<bool>(false);

  bool _isUsersExpanded = false;
  bool _isTasksExpanded = false;

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
    FlutterBackgroundService()
        .invoke(BackgroundChannelCommand.track.toString());
    EventManager.listen<DataChannel>(onTracking);
    EventManager.listen<EventOnRender>(onRender);
    super.initState();
  }

  ///
  @override
  void dispose() {
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
      ListTile(
          titleTextStyle: Theme.of(context).textTheme.titleLarge,
          subtitleTextStyle: Theme.of(context).textTheme.titleLarge,
          leading: statusTrigger(),
          trailing: const SizedBox(height: 10, width: 10),
          title: widgetTrackingStatus(),
          subtitle: Column(
            children: [widgetDate(), widgetDuration()],
          )),
      AppWidgets.divider(),
      widgetAddress(),
      ListTile(
          title: Column(children: [
        widgetAliases(),
        AppWidgets.divider(),
        widgetSelectedTasks(),
        widgetSelectedUsers(),
        AppWidgets.divider(),
        widgetTrackpointNotes()
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
                backgroundColor: AppColors.warningBackground.color,
                color: AppColors.warningForeground.color));
  }

  Widget statusTrigger() {
    double? size = Theme.of(context).iconTheme.size;
    if (size != null) {
      size *= 2;
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
                    size: size),
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
                    dataChannel.trackingStatusTrigger != TrackingStatus.none
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

  Widget widgetTrackingStatus() {
    return Center(
        child: ListenableBuilder(
            listenable: _listenableTrackingStatus,
            builder: (context, child) {
              return Text('${dataChannel.trackingStatus.name.toUpperCase()}\n');
            }));
  }

  Widget widgetDate() {
    return ListenableBuilder(
        listenable: _listenableDate,
        builder: (context, child) {
          return Text(util.formatDate(DateTime.now()));
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
                  await Cache.addressMostRecent.save<String>(address.alias);
              dataChannel.fullAddress = await Cache.addressFullMostRecent
                  .save<String>(address.description);
              setState(() {});
              if (mounted) {
                AppWidgets.dialog(context: context, contents: [
                  ListTile(
                      title: const Text('Address'),
                      subtitle: Text(address.alias),
                      trailing: IconButton(
                        icon: const Icon(Icons.copy),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: address.alias));
                        },
                      )),
                  ListTile(
                      title: const Text('Address Details'),
                      subtitle: Text(address.description),
                      trailing: IconButton(
                        icon: const Icon(Icons.copy),
                        onPressed: () {
                          Clipboard.setData(
                              ClipboardData(text: address.description));
                        },
                      )),
                ], buttons: [
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
              child: Text(dataChannel.address),
              onPressed: () {
                AppWidgets.dialog(context: context, contents: [
                  ListTile(
                      title: Text(dataChannel.fullAddress),
                      trailing: IconButton(
                        icon: const Icon(Icons.copy),
                        onPressed: () {
                          Clipboard.setData(
                              ClipboardData(text: dataChannel.fullAddress));
                        },
                      ))
                ], buttons: [
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
    for (var channelModel in dataChannel.aliasList) {
      i++;
      list.add(ListTile(
          leading: Icon(Icons.square, color: channelModel.model.privacy.color),
          title: Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.editAlias.route,
                            arguments: channelModel.model.id)
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
                    '${channelModel.distance}m: ${channelModel.model.title}',
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
      title: ElevatedButton(
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
      title: ElevatedButton(
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
                                          arguments: channelModel.id)
                                      .then((value) {
                                    if (mounted) {
                                      render();
                                    }
                                  });
                                },
                              )),
                          subtitle: channelModel.shared.notes.isEmpty
                              ? null
                              : Text(channelModel.shared.notes,
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

  Future<void> dialogSelectUser() async {
    List<int> modelIds = dataChannel.userList.map<int>((e) => e.id).toList();
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
      title: ElevatedButton(
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
        dataChannel.taskList.isEmpty ? Color.fromARGB(0, 0, 0, 0) : null;
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
      title: ElevatedButton(
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
                                          arguments: channelModel.id)
                                      .then((value) {
                                    if (mounted) {
                                      render();
                                    }
                                  });
                                },
                              )),
                          subtitle: channelModel.shared.notes.isEmpty
                              ? null
                              : Text(channelModel.shared.notes,
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

  Future<void> editTaskNotes(ChannelTask channelModel) async {
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
                SharedTrackpointTask.addOrUpdate(channelModel.model,
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

  Future<void> dialogSelectTask() async {
    List<int> modelIds = dataChannel.taskList.map<int>((e) => e.id).toList();
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
  final _userNotesUndoController = UndoHistoryController();
  Widget widgetTrackpointNotes() {
    _userNotesController?.text = dataChannel.notes;
    return ListTile(
        trailing: ListenableBuilder(
            listenable: _listenableUndoUserNotes,
            builder: (context, child) {
              return IconButton(
                icon: const Icon(Icons.undo),
                onPressed: _userNotesUndoController.value.canUndo
                    ? () {
                        _userNotesUndoController.undo();
                      }
                    : null,
              );
            }),
        title: TextField(
          controller: _userNotesController ??=
              TextEditingController(text: dataChannel.notes),
          undoController: _userNotesUndoController,
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
