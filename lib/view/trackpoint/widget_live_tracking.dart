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

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:visibility_detector/visibility_detector.dart';

//import 'package:chaostours/location.dart';
import 'package:chaostours/channel/data_channel.dart';
import 'package:chaostours/model/model_trackpoint.dart';
import 'package:chaostours/tracking.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/conf/app_routes.dart';
import 'package:chaostours/event_manager.dart';
import 'package:chaostours/database/cache.dart';
import 'package:chaostours/util.dart' as util;
import 'package:chaostours/model/model_alias.dart';
import 'package:chaostours/model/model_task.dart';
import 'package:chaostours/model/model_user.dart';
import 'package:chaostours/view/app_widgets.dart';
import 'package:chaostours/address.dart' as addr;
import 'package:chaostours/gps.dart';
import 'package:chaostours/conf/app_user_settings.dart';

class WidgetTrackingPage extends StatefulWidget {
  const WidgetTrackingPage({super.key});

  @override
  State<WidgetTrackingPage> createState() => _WidgetTrackingPage();
}

///
///
///
///
///

class _Cache {
  // static final Logger logger = Logger.logger<_Cache>();

  static Duration averageDuration = Duration.zero;
  //static GPS? lastTrackpointStanding;
  static List<GPS> gpsPoints = [];
  //static List<GPS> gpsSmoothPoints = [];
  static List<GPS> gpsCalcPoints = [];
  static get distanceMoving => GPS.distanceOverTrackList(gpsPoints);
  //static GPS? lastTrackpointStanding;
  static get distanceStanding => GPS.distanceOverTrackList(gpsPoints);
  static TrackingStatus trackingStatus = TrackingStatus.none;
  static TrackingStatus triggeredTrackingStatus = TrackingStatus.none;
  static List<String> weekdays = Weekdays.mondayFirst.weekdays;
  static String address = '';
  //static String notes = '';
  static int distanceTreshold = 0;
  static Duration timeRangeTreshold = Duration.zero;

  /// non Cache values
  static GPS? gps;
  static ModelTrackPoint? trackPoint;
  //static Location? location;

  static Future<bool> reload() async {
    //logger.log('-------reload live tracking cache -------');
    gps = await GPS.gps();

    //location = await Location.location(gps!);
    trackPoint = await ModelTrackPoint.fromCache(gps!);

    gpsPoints = await Cache.backgroundGpsPoints.load<List<GPS>>([]);
    //gpsSmoothPoints = await Cache.backgroundGpsSmoothPoints.load<List<GPS>>([]);
    gpsCalcPoints = await Cache.backgroundGpsCalcPoints.load<List<GPS>>([]);

    //lastTrackpointStanding = await Cache.backgroundGpsStartStanding.load<GPS>(gps!);
    trackingStatus = await Cache.backgroundTrackingStatus
        .load<TrackingStatus>(TrackingStatus.none);
    triggeredTrackingStatus = await Cache.trackingStatusTriggered
        .load<TrackingStatus>(TrackingStatus.none);

    address = await Cache.backgroundAddress.load<String>('Reload');
    //notes = await Cache.backgroundTrackPointUserNotes.load<String>('');

    Cache cache = Cache.appSettingWeekdays;
    weekdays = (await cache
            .load<Weekdays>(AppUserSetting(cache).defaultValue as Weekdays))
        .weekdays;

    cache = Cache.appSettingDistanceTreshold;
    distanceTreshold =
        await cache.load<int>(AppUserSetting(cache).defaultValue as int);

    cache = Cache.appSettingTimeRangeTreshold;
    timeRangeTreshold = await cache
        .load<Duration>(AppUserSetting(cache).defaultValue as Duration);

    return true;
  }
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
  final _listenableSelectedTasks = ValueNotifier<int>(0);
  final _listenableSelectedUsers = ValueNotifier<int>(0);
  final _listenableDuration = ValueNotifier<int>(0);
  final _listenableDate = ValueNotifier<int>(0);
  final _listenableStatus = ValueNotifier<int>(0);

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
    EventManager.remove<DataChannel>(onTracking);
    super.dispose();
  }

  ///
  void onTracking(DataChannel dataChannel) {
    if (_visibleFraction < .5) {
      return;
    }
    trackingListener.value++;
  }

  ///
  void onRender(EventOnRender _) {
    if (_visibleFraction < .5) {
      return;
    }
    renderListener.value++;
  }

  ///
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _Cache.reload(),
      builder: (context, snapshot) {
        return AppWidgets.checkSnapshot(context, snapshot) ?? body();
      },
    );
  }

  Widget body() {
    Widget widget;
    try {
      switch (_Cache.trackingStatus) {
        case TrackingStatus.standing:
          widget = ListenableBuilder(
            listenable: trackingListener,
            builder: (context, child) =>
                const Text('under construction'), //renderTrackPointStanding(),
          );
          break;

        case TrackingStatus.moving:
          widget = ListenableBuilder(
            listenable: trackingListener,
            builder: (context, child) =>
                const Text('under construction'), // renderTrackPointMoving(),
          );
          break;

        default:
          widget = AppWidgets.loadingScreen(
              context, const Text('Waiting for Tracking Status'));
      }
    } catch (e, stk) {
      widget = AppWidgets.loadingScreen(
          context, Text('Error render Trackpoint: $e\n$stk'));
    }

    widget = VisibilityDetector(
        key: _visibilityDetectorKey,
        child: widget,
        onVisibilityChanged: (VisibilityInfo info) {
          _visibleFraction = info.visibleFraction;
        });

    return AppWidgets.scaffold(context,
        body: widget,
        navBar: bottomNavBar(context),
        appBar: AppBar(title: const Text('Live Tracking')));
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

  Widget renderAliases() {
    List<Widget> list = [];
    for (var model in _Cache.trackPoint!.aliasModels) {
      list.add(Text('(${GPS.distance(_Cache.gps!, model.gps)}m) ${model.title}',
          style: TextStyle(
              color: model.visibility.color, backgroundColor: Colors.grey)));
    }
    return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: list);
  }

  Widget widgetTrackingStatus() {
    return ListenableBuilder(
        listenable: _listenableStatus,
        builder: (context, child) {
          return Text(DataChannel().trackingStatus.name.toUpperCase());
        });
  }

  Widget widgetDate() {
    return ListenableBuilder(
        listenable: _listenableDate,
        builder: (context, child) {
          return Text(util.formatDate(DateTime.now()));
        });
  }

  Widget widgetDuration() {
    return ListenableBuilder(
        listenable: _listenableDuration,
        builder: (context, child) {
          return Text(util.formatDuration(DataChannel().duration));
        });
  }

  Widget widgetselectedUsers() {
    return ListenableBuilder(
      listenable: _listenableSelectedUsers,
      builder: (context, child) {
        return ListTile(
            trailing: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                await editSelectedUsers();
                _listenableSelectedUsers.value++;
              },
            ),
            title: Column(
              children: DataChannel().userList.map<Widget>(
                (model) {
                  return TextButton(
                    child: Text(model.title),
                    onPressed: () {
                      Navigator.pushNamed(context, AppRoutes.editUser.route,
                              arguments: model.id)
                          .then((value) => _listenableSelectedUsers.value++);
                    },
                  );
                },
              ).toList(),
            ));
      },
    );
  }

  Widget widgetselectedTasks() {
    return ListenableBuilder(
        listenable: _listenableSelectedTasks,
        builder: (context, child) {
          return ListTile(
              trailing: IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () async {
                  await editSelectedTasks();
                  _listenableSelectedTasks.value++;
                },
              ),
              title: Column(
                children: DataChannel().taskList.map<Widget>(
                  (model) {
                    return TextButton(
                      child: Text(model.title),
                      onPressed: () {
                        Navigator.pushNamed(context, AppRoutes.editUser.route,
                                arguments: model.id)
                            .then((value) => _listenableSelectedTasks.value++);
                      },
                    );
                  },
                ).toList(),
              ));
        });
  }

  final _userNotesUndoController = UndoHistoryController();
  final _listenableUserNotes = ValueNotifier<int>(0);
  Widget widgetUserNotes() {
    return ListTile(
        trailing: ListenableBuilder(
            listenable: _listenableUserNotes,
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
              TextEditingController(text: DataChannel().notes),
          undoController: _userNotesUndoController,
          minLines: 2,
          maxLines: 6,
          decoration: const InputDecoration(hintText: 'Notes'),
          onEditingComplete: () async {
            DataChannel().notes =
                await Cache.backgroundTrackPointUserNotes.load<String>('');
          },
        ));
  }

  Future<void> editSelectedUsers() async {}
  Future<void> editSelectedTasks() async {}

  ///
  Widget _renderTrackPointMoving() {
    ModelTrackPoint tp = _Cache.trackPoint!;

    Widget body =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Center(
          child: Text('\n${_Cache.weekdays[tp.timeStart.weekday]}. den'
              ' ${tp.timeStart.day}.${tp.timeStart.month}.${tp.timeStart.year}')),
      const Center(
          heightFactor: 2,
          child:
              Text('Moving', style: TextStyle(letterSpacing: 2, fontSize: 20))),
      Center(
          heightFactor: 1.5,
          child: Text('${_Cache.distanceMoving} km',
              style: const TextStyle(letterSpacing: 2, fontSize: 15))),
      Center(
          heightFactor: 1.5,
          child: Text(
              'Treshold: ${GPS.distanceOverTrackList(_Cache.gpsCalcPoints).round()}m of ${_Cache.distanceTreshold}m in ${_Cache.timeRangeTreshold.inSeconds}s',
              style: const TextStyle(letterSpacing: 2, fontSize: 15))),
      Center(
          child: Text(
              '${tp.timeStart.hour}:${tp.timeStart.minute} - ${tp.timeEnd.hour}:${tp.timeEnd.minute}')),
    ]);
    List<Widget> items = [
      divider,
      TextButton(
        style: ButtonStyle(
            padding:
                MaterialStateProperty.all<EdgeInsets>(const EdgeInsets.all(0))),
        child: renderAliases(),
        onPressed: () {
          _Cache.reload().then(
            (value) => render(),
          );
        },
      ),
      divider,
      TextButton(
        style: ButtonStyle(
            padding:
                MaterialStateProperty.all<EdgeInsets>(const EdgeInsets.all(0))),
        child: Text('OSM:\n${_Cache.address}'),
        onPressed: () async {
          _Cache.reload().then(
            (value) => render(),
          );
        },
      ),
    ];

    return ListView(children: [
      ListTile(
          //contentPadding: EdgeInsets.fromLTRB(0, 0, 0, 0),
          horizontalTitleGap: -30,
          leading: Stack(children: [
            IconButton(
                icon: Icon(
                    _Cache.triggeredTrackingStatus == TrackingStatus.standing
                        ? Icons.warning
                        : Icons.warning_amber),
                onPressed: () async {
                  if (_Cache.triggeredTrackingStatus !=
                      TrackingStatus.standing) {
                    Fluttertoast.showToast(msg: 'Standing sheduled');
                  }
                  _Cache.triggeredTrackingStatus = await Cache
                      .trackingStatusTriggered
                      .save(TrackingStatus.standing);
                  render();
                }),
            Container(
                padding: const EdgeInsets.fromLTRB(8, 35, 0, 0),
                child: const Text('STOP', style: TextStyle(fontSize: 10)))
          ]),
          title: body),
      ...items
    ]);
  }

  ///
  Widget _renderTrackPointStanding() {
    ModelTrackPoint tp = _Cache.trackPoint!;
    Widget body =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Center(
          child: Text('\n${_Cache.weekdays[tp.timeStart.weekday]}. den'
              ' ${tp.timeStart.day}.${tp.timeStart.month}.${tp.timeStart.year}')),
      const Center(
          heightFactor: 2,
          child: Text('Standing',
              style: TextStyle(letterSpacing: 2, fontSize: 20))),
      Center(child: Text(util.formatDuration(tp.duration))),
      Center(
          child: Text(
              '${tp.timeStart.hour}:${tp.timeStart.minute} - ${tp.timeEnd.hour}:${tp.timeEnd.minute}')),
      Center(
          heightFactor: 1.5,
          child: Text('Distance: ${_Cache.distanceStanding}m',
              style: const TextStyle(letterSpacing: 2, fontSize: 15))),
    ]);

    List<Widget> items = [
      divider,

      /// alias
      TextButton(
        style: ButtonStyle(
            alignment: Alignment.centerLeft,
            padding: MaterialStateProperty.all<EdgeInsets>(
                const EdgeInsets.fromLTRB(30, 0, 20, 0))),
        child: renderAliases(),
        onPressed: () async {
          await _Cache.reload();
          render();
        },
      ),
      divider,

      /// osm
      TextButton(
        style: ButtonStyle(
            alignment: Alignment.centerLeft,
            padding: MaterialStateProperty.all<EdgeInsets>(
                const EdgeInsets.fromLTRB(30, 0, 20, 0))),
        child: Text('OSM:\n${_Cache.address}'),
        onPressed: () async {
          if (_Cache.gpsPoints.isNotEmpty) {
            var gps = _Cache.gpsPoints.first;
            var address = (await addr.Address(gps).lookup(
                    OsmLookupConditions.onUserRequest,
                    saveToCache: true))
                .alias;
            _Cache.address =
                await Cache.backgroundAddress.save<String>(address);
            render();
          }
        },
      ),
      divider,
      dropdownTasks(),
      divider,
      dropdownUser(),
      divider,
      userNotes(),
    ];

    return ListView(children: [
      ListTile(
          //contentPadding: EdgeInsets.fromLTRB(0, 0, 0, 0),
          horizontalTitleGap: -30,
          leading: Stack(children: [
            IconButton(
                icon: Icon(
                    _Cache.triggeredTrackingStatus == TrackingStatus.moving
                        ? Icons.drive_eta
                        : Icons.drive_eta_outlined),
                onPressed: () async {
                  if (_Cache.triggeredTrackingStatus != TrackingStatus.moving) {
                    Fluttertoast.showToast(msg: 'Moving sheduled');
                  }
                  _Cache.triggeredTrackingStatus = await Cache
                      .trackingStatusTriggered
                      .save(TrackingStatus.moving);
                  render();
                }),
            Container(
                padding: const EdgeInsets.fromLTRB(4, 35, 0, 0),
                child: const Text('START', style: TextStyle(fontSize: 10)))
          ]),
          title: body),
      ...items
    ]);
  }

  ///
  List<Widget> _taskCheckboxes() {
    var referenceList = _Cache.trackPoint!.taskIds;
    var checkBoxes = <Widget>[];
    for (var model in _Cache.trackPoint!.taskModels) {
      if (model.isActive) {
        checkBoxes.add(AppWidgets.checkboxListTile(util.CheckboxController(
            idReference: model.id,
            referenceList: referenceList,
            isActive: model.isActive,
            title: model.title,
            subtitle: model.description,
            onToggle: (bool? checked) async {
              await _Cache.reload();
              render();
            })));
      }
    }
    return checkBoxes;
  }

  ///
  List<Widget> userCheckboxes() {
    var referenceList = _Cache.trackPoint!.userIds;
    var checkBoxes = <Widget>[];
    for (var model in _Cache.trackPoint!.userModels) {
      if (model.isActive) {
        checkBoxes.add(AppWidgets.checkboxListTile(util.CheckboxController(
            idReference: model.id,
            referenceList: referenceList,
            isActive: model.isActive,
            title: model.title,
            subtitle: model.description,
            onToggle: (bool? checked) async {
              await _Cache.reload();
              render();
            })));
      }
    }
    return checkBoxes;
  }

  ///
  bool dropdownUserIsOpen = false;
  Widget dropdownUser() {
    /// render selected users

    List<ModelUser> userModels = [];
    for (var model in userModels) {
      if (_Cache.trackPoint!.userIds.contains(model.id)) {
        userModels.add(model);
      }
    }
    //userModels.sort((a, b) => a.sortOrder - b.sortOrder);
    var userList = userModels.map((e) => e.title);
    String users = userList.isNotEmpty ? '\n- ${userList.join('\n- ')}' : ' - ';

    /// dropdown menu botten with selected users
    List<Widget> items = [
      ElevatedButton(
        child: ListTile(
          trailing: const Icon(Icons.menu),
          title: Text(dropdownUserIsOpen ? '' : 'Staff:$users'),
          subtitle:
              !dropdownUserIsOpen ? null : Column(children: userCheckboxes()),
        ),
        onPressed: () {
          dropdownUserIsOpen = !dropdownUserIsOpen;
          render();
        },
      ),
    ];

    return ListBody(children: items);
  }

  ///
  bool dropdownTasksIsOpen = false;
  Widget dropdownTasks() {
    /// render selected tasks
    List<ModelTask> taskModels = [];
    for (var item in taskModels) {
      if (_Cache.trackPoint!.taskIds.contains(item.id)) {
        taskModels.add(item);
      }
    }
    //taskModels.sort((a, b) => a.sortOrder - b.sortOrder);
    var taskList = taskModels.map(
      (e) => e.title,
    );
    String tasks = taskList.isNotEmpty ? '\n- ${taskList.join('\n- ')}' : ' - ';

    /// dropdown menu botten with selected tasks
    List<Widget> items = [
      ElevatedButton(
        child: ListTile(
          trailing: const Icon(Icons.menu),
          title: Text(dropdownTasksIsOpen ? '' : 'Tasks:$tasks'),
          subtitle: !dropdownTasksIsOpen
              ? null
              : const Column(children: [AppWidgets.empty]),
        ),
        onPressed: () {
          dropdownTasksIsOpen = !dropdownTasksIsOpen;
          render();
        },
      ),
    ];

    return ListBody(children: items);
  }

  ///
  Widget userNotes() {
    return Container(
        padding: const EdgeInsets.all(10),
        child: TextField(
            decoration: const InputDecoration(
                label: Text('Notes'),
                contentPadding: EdgeInsets.all(2),
                border: InputBorder.none),
            //expands: true,
            maxLines: null,
            minLines: 2,
            controller: _userNotesController,
            onChanged: (String? s) async {
              render();
            }));
  }
}
