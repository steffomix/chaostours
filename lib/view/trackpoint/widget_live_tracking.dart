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

import 'package:chaostours/address.dart';
import 'package:chaostours/conf/app_user_settings.dart';
import 'package:chaostours/gps.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'package:chaostours/channel/data_channel.dart';
import 'package:chaostours/tracking.dart';
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

  double _visibleFraction = 100.0;
  final _visibilityDetectorKey =
      GlobalKey(debugLabel: 'Life Tracking VisibilityDetectorKey');

  TextEditingController? _userNotesController;
  final trackingListener = ValueNotifier<int>(0);
  final renderListener = ValueNotifier<int>(0);
  final addressIsLoading = ValueNotifier<bool>(false);

  final Map<String, ValueNotifier<int>> widgetNotifiers = {};

  Future<void> render() async {
    if (mounted) {
      setState(() {});
    }
  }

  ///
  @override
  void initState() {
    renderListener.addListener(() {});
    trackingListener.addListener(() {});

    EventManager.listen<DataChannel>(onTracking);
    EventManager.listen<EventOnRender>(onRender);
    super.initState();
  }

  ///
  @override
  void dispose() {
    renderListener.dispose();
    trackingListener.dispose();
    widgetNotifiers.values.map(
      (e) => e.dispose,
    );
    EventManager.remove<DataChannel>(onTracking);
    super.dispose();
  }

  ///
  void onTracking(DataChannel dataChannel) {
    if (mounted) {
      if (_visibleFraction < .5) {
        return;
      }
      trackingListener.value++;
    }
  }

  ///
  void onRender(EventOnRender _) {
    if (mounted) {
      if (_visibleFraction < .5) {
        return;
      }
      renderListener.value++;
    }
  }

  ///
  @override
  Widget build(BuildContext context) {
    Widget widget = VisibilityDetector(
        key: _visibilityDetectorKey,
        child: ListView(
          children: [
            initialized(),
            Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
              widgetDate(),
              widgetTrackingStatus(),
              ListTile(leading: statusTrigger(), title: widgetDuration()),
              widgetAliases(),
              widgetAddress(),
              widgetselectedUsers(),
              widgetselectedTasks(),
              widgetUserNotes()
            ])
          ],
        ),
        onVisibilityChanged: (VisibilityInfo info) {
          _visibleFraction = info.visibleFraction;
        });

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
    return ListenableBuilder(
      listenable: widgetNotifiers['statusTrigger'] ??= ValueNotifier<int>(0),
      builder: (context, child) {
        return dataChannel.trackingStatus == TrackingStatus.standing
            ? IconButton(
                icon: Icon(dataChannel.statusTrigger == TrackingStatus.moving
                    ? Icons.drive_eta
                    : Icons.drive_eta_outlined),
                onPressed: () async {
                  if (dataChannel.statusTrigger != TrackingStatus.moving) {
                    Fluttertoast.showToast(msg: 'Moving sheduled');
                  }
                  dataChannel.statusTrigger = await Cache
                      .trackingStatusTriggered
                      .save(TrackingStatus.moving);
                  widgetNotifiers['statusTrigger']?.value++;
                })
            : IconButton(
                icon: const Icon(Icons.flag),
                onPressed: () async {
                  AppWidgets.dialog(context: context, contents: [
                    const Text('Create Trackpoint right here?')
                  ], buttons: [
                    TextButton(
                      child: const Text('Yes'),
                      onPressed: () {},
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
    return ListenableBuilder(
        listenable: widgetNotifiers['trackingStatus'] ??= ValueNotifier<int>(0),
        builder: (context, child) {
          return Text(dataChannel.trackingStatus.name.toUpperCase());
        });
  }

  Widget widgetDate() {
    return ListenableBuilder(
        listenable: widgetNotifiers['date'] ??= ValueNotifier<int>(0),
        builder: (context, child) {
          return Text(util.formatDate(DateTime.now()));
        });
  }

  Widget widgetDuration() {
    return ListenableBuilder(
        listenable: widgetNotifiers['duration'] ??= ValueNotifier<int>(0),
        builder: (context, child) {
          return Text(util.formatDuration(dataChannel.duration));
        });
  }

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
            } catch (e, stk) {
              logger.error('update address: $e', stk);
            }
            addressIsLoading.value = false;
          },
        ),
        title: TextButton(
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
        ));
  }

  Widget widgetAliases() {
    return ListenableBuilder(
        listenable: widgetNotifiers['aliases'] ??= ValueNotifier<int>(0),
        builder: (context, child) {
          List<Widget> list = [];
          for (var model in dataChannel.aliasList) {
            list.add(TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, AppRoutes.editAlias.route,
                          arguments: model.id)
                      .then(
                    (value) {
                      render();
                    },
                  );
                },
                child: Text('${dataChannel.distance}m: ${model.title}',
                    style: TextStyle(
                        color: model.visibility.color,
                        backgroundColor: Colors.grey))));
          }
          return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: list);
        });
  }

  Widget widgetselectedUsers() {
    const listenerId = 'selectedUsers';
    return ListenableBuilder(
      listenable: widgetNotifiers[listenerId] ??= ValueNotifier<int>(0),
      builder: (context, child) {
        return ListTile(
            trailing: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                await editSelectedUsers();
                widgetNotifiers[listenerId]?.value++;
              },
            ),
            title: Column(
              children: dataChannel.userList.map<Widget>(
                (model) {
                  return TextButton(
                    child: Text(model.title),
                    onPressed: () {
                      Navigator.pushNamed(context, AppRoutes.editUser.route,
                              arguments: model.id)
                          .then(
                              (value) => widgetNotifiers[listenerId]?.value++);
                    },
                  );
                },
              ).toList(),
            ));
      },
    );
  }

  Widget widgetselectedTasks() {
    const listenerId = 'seletedTsaks';
    return ListenableBuilder(
        listenable: widgetNotifiers[listenerId] ??= ValueNotifier<int>(0),
        builder: (context, child) {
          return ListTile(
              trailing: IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () async {
                  await editSelectedTasks();
                  widgetNotifiers[listenerId]?.value++;
                },
              ),
              title: Column(
                children: dataChannel.taskList.map<Widget>(
                  (model) {
                    return TextButton(
                      child: Text(model.title),
                      onPressed: () {
                        Navigator.pushNamed(context, AppRoutes.editUser.route,
                                arguments: model.id)
                            .then((value) =>
                                widgetNotifiers[listenerId]?.value++);
                      },
                    );
                  },
                ).toList(),
              ));
        });
  }

  final _userNotesUndoController = UndoHistoryController();
  Widget widgetUserNotes() {
    return ListTile(
        trailing: ListenableBuilder(
            listenable: widgetNotifiers['userNotes'] ??= ValueNotifier<int>(0),
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
          onEditingComplete: () async {
            dataChannel.notes =
                await Cache.backgroundTrackPointUserNotes.load<String>('');
          },
        ));
  }

  Future<void> editSelectedUsers() async {}
  Future<void> editSelectedTasks() async {}

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
