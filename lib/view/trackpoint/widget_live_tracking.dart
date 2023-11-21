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

import 'package:chaostours/conf/app_colors.dart';
import 'package:chaostours/model/model_trackpoint.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:visibility_detector/visibility_detector.dart';
//
import 'package:chaostours/location.dart';
import 'package:chaostours/tracking.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/conf/app_routes.dart';
import 'package:chaostours/event_manager.dart';
import 'package:chaostours/cache.dart';
import 'package:chaostours/util.dart';
import 'package:chaostours/model/model_alias.dart';
import 'package:chaostours/model/model_task.dart';
import 'package:chaostours/model/model_user.dart';
//
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
  //static GPS? lastTrackpointStanding;
  static List<GPS> gpsPoints = [];
  static List<GPS> gpsSmoothPoints = [];
  static List<GPS> gpsCalcPoints = [];
  static get distanceMoving => GPS.distanceOverTrackList(gpsPoints);
  static GPS? lastTrackpointStanding;
  static get distanceStanding => GPS.distanceOverTrackList(gpsPoints);
  static TrackingStatus trackingStatus = TrackingStatus.none;
  static TrackingStatus triggeredTrackingStatus = TrackingStatus.none;
  static List<String> weekdays = Weekdays.mondayFirst.weekdays;
  static String address = '';
  static String notes = '';
  static int distanceTreshold = 0;
  static Duration timeRangeTreshold = Duration.zero;

  /// non Cache values
  static GPS? gps;
  static ModelTrackPoint? trackPoint;
  static Location? location;

  static Future<bool> reload() async {
    gps = await GPS.gps();
    location = await Location.location(gps!);
    trackPoint = await ModelTrackPoint.fromCache(gps!);

    gpsPoints = await Cache.backgroundGpsPoints.load<List<GPS>>([]);
    gpsSmoothPoints = await Cache.backgroundGpsSmoothPoints.load<List<GPS>>([]);
    gpsCalcPoints = await Cache.backgroundGpsCalcPoints.load<List<GPS>>([]);

    lastTrackpointStanding =
        await Cache.backgroundGpsStartStanding.load<GPS>(gps!);
    trackingStatus = await Cache.backgroundTrackingStatus
        .load<TrackingStatus>(TrackingStatus.none);
    triggeredTrackingStatus = await Cache.trackingStatusTriggered
        .load<TrackingStatus>(TrackingStatus.none);

    address = await Cache.backgroundAddress.load<String>('Reload');
    notes = await Cache.backgroundTrackPointUserNotes.load<String>('');

    Cache cache = Cache.appSettingWeekdays;
    weekdays = (await cache
            .load<Weekdays>(AppUserSettings(cache).defaultValue as Weekdays))
        .weekdays;

    cache = Cache.appSettingDistanceTreshold;
    distanceTreshold =
        await cache.load<int>(AppUserSettings(cache).defaultValue as int);

    cache = Cache.appSettingTimeRangeTreshold;
    timeRangeTreshold = await cache
        .load<Duration>(AppUserSettings(cache).defaultValue as Duration);

    return true;
  }
}

class _WidgetTrackingPage extends State<WidgetTrackingPage> {
  static final Logger logger = Logger.logger<WidgetTrackingPage>();

  static int _bottomBarIndex = 0;

  Widget divider = AppWidgets.divider();

  double? _visibleFraction;
  final _visibilityDetectorKey =
      GlobalKey(debugLabel: 'Life Tracking VisibilityDetectorKey');

  /// editable fields
  final _tpNotes = TextEditingController();

  Future<void> render() async {
    if (mounted) {
      setState(() {});
    } else {
      logger.warn('setState - not mounted');
    }
  }

  ///
  @override
  void initState() {
    EventManager.listen<EventOnAppTick>(onTick);
    EventManager.listen<EventOnTrackingStatusChanged>(onTrackingStatusChanged);
    super.initState();
  }

  ///
  @override
  void dispose() {
    EventManager.remove<EventOnAppTick>(onTick);
    EventManager.remove<EventOnTrackingStatusChanged>(onTrackingStatusChanged);
    super.dispose();
  }

  void onTrackingStatusChanged(EventOnTrackingStatusChanged e) {
    if ((_visibleFraction ?? 0) < 50) {
      return;
    }
    _tpNotes.text = _Cache.notes;
    render();
  }

  ///
  void onTick(EventOnAppTick tick) {
    if ((_visibleFraction ?? 0) < 50) {
      return;
    }
    render();
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
          widget = renderTrackPointStanding();
          break;

        case TrackingStatus.moving:
          widget = renderTrackPointMoving();
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
            case 0: // 2.
              Navigator.pushNamed(context, AppRoutes.listTrackpoints.route)
                  .then(
                (value) => render(),
              );
              break;
            case 1: // 3.
              Navigator.pushNamed(context, AppRoutes.osm.route).then(
                (value) => render(),
              );
              break;
            default: // 5.
          }
          _bottomBarIndex = id;
          render();
        });
  }

  Widget renderAliases() {
    List<Widget> list = [];
    for (var model in _Cache.trackPoint!.aliasModels) {
      Color color;
      switch (model.visibility) {
        case AliasVisibility.public:
          color = AppColors.aliasPublic.color;
          break;

        case AliasVisibility.privat:
          color = AppColors.aliasPrivate.color;
          break;

        default:
          color = AppColors.aliasRestricted.color;
      }
      list.add(Text('(${GPS.distance(_Cache.gps!, model.gps)}m) ${model.title}',
          style: TextStyle(color: color, backgroundColor: Colors.grey)));
    }
    return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: list);
  }

  ///
  Widget renderTrackPointMoving() {
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
  Widget renderTrackPointStanding() {
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
      Center(child: Text(tp.durationText)),
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
            var address = (await addr.Address(gps).lookupAddress()).toString();
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
  List<Widget> taskCheckboxes() {
    var referenceList = _Cache.trackPoint!.taskIds;
    var checkBoxes = <Widget>[];
    for (var model in _Cache.trackPoint!.taskModels) {
      if (model.isActive) {
        checkBoxes.add(AppWidgets.checkboxListTile(CheckboxController(
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
        checkBoxes.add(AppWidgets.checkboxListTile(CheckboxController(
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
          subtitle:
              !dropdownTasksIsOpen ? null : Column(children: taskCheckboxes()),
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
            controller: _tpNotes,
            onChanged: (String? s) async {
              _Cache.notes = await Cache.backgroundTrackPointUserNotes
                  .save<String>(_tpNotes.text);
              render();
            }));
  }
}
