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

  double _visibleFraction = 100.0;
  final _visibilityDetectorKey =
      GlobalKey(debugLabel: 'Life Tracking VisibilityDetectorKey');

  TextEditingController? _userNotesController;
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
    EventManager.listen<DataChannel>(onTracking);
    EventManager.listen<EventOnRender>(onRender);
    super.initState();
  }

  ///
  @override
  void dispose() {
    widgetNotifiers.values.map(
      (e) => e.dispose,
    );
    EventManager.remove<EventOnRender>(onRender);
    EventManager.remove<DataChannel>(onTracking);
    super.dispose();
  }

  ///
  void onTracking(DataChannel dataChannel) {
    if (mounted) {
      setState(() {});
      if (_visibleFraction < .5) {
        return;
      }
      widgetNotifiers.values.map((e) => e.value++);
    }
  }

  ///
  void onRender(EventOnRender _) {
    if (mounted) {
      if (_visibleFraction < .5) {
        return;
      }
      widgetNotifiers.values.map((e) => e.value++);
    }
  }

  ///
  @override
  Widget build(BuildContext context) {
    //return AppWidgets.scaffold(context, body: AppWidgets.empty);
    /* Widget widget = VisibilityDetector(
        key: _visibilityDetectorKey,
        child: Column(children: [
          Center(child: initialized()),
          Column(children: [
            ListTile(
                leading: statusTrigger(),
                title: widgetTrackingStatus(),
                subtitle: Column(
                  children: [widgetDate(), widgetDuration()],
                ))
          ]),
          widgetAliases(),
          widgetAddress(),
          widgetselectedUsers(),
          widgetselectedTasks(),
          widgetUserNotes()
        ]),
        onVisibilityChanged: (VisibilityInfo info) {
          _visibleFraction = info.visibleFraction;
        });
 */

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
        widgetselectedUsers(),
        widgetselectedTasks(),
        widgetUserNotes()
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
    return Center(
        child: ListenableBuilder(
            listenable: widgetNotifiers['trackingStatus'] ??=
                ValueNotifier<int>(0),
            builder: (context, child) {
              return Text('${dataChannel.trackingStatus.name.toUpperCase()}\n');
            }));
  }

  Widget widgetDate() {
    return ListenableBuilder(
        listenable: widgetNotifiers['date'] ??= ValueNotifier<int>(0),
        builder: (context, child) {
          return Text(util.formatDate(DateTime.now()));
        });
  }

  Widget widgetDuration() {
    return Center(
        child: ListenableBuilder(
            listenable: widgetNotifiers['duration'] ??= ValueNotifier<int>(0),
            builder: (context, child) {
              return Text(util.formatDuration(dataChannel.duration));
            }));
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

              dataChannel.address =
                  await Cache.backgroundAddress.save<String>(address.alias);
              dataChannel.fullAddress =
                  await Cache.backgroundAddress.save<String>(address.alias);
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

  Widget widgetAliases() {
    return ListenableBuilder(
        listenable: widgetNotifiers['aliases'] ??= ValueNotifier<int>(0),
        builder: (context, child) {
          List<Widget> list = [const Center(child: Text('Alias'))];
          var i = 0;
          for (var model in dataChannel.modelAliasList) {
            i++;
            list.add(ListTile(
                leading: Icon(Icons.square, color: model.privacy.color),
                title: Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                        onPressed: () {
                          Navigator.pushNamed(
                                  context, AppRoutes.editAlias.route,
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
                          '${dataChannel.distance}m: ${model.title}',
                        )))));
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
              children: dataChannel.modelUserList.map<Widget>(
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
                children: dataChannel.modelTaskList.map<Widget>(
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
              _userNotesController?.text = dataChannel.notes;
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
