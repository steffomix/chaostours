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

import 'package:chaostours/Location.dart';
import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart' as osm;
import 'package:fluttertoast/fluttertoast.dart';
//
import 'package:chaostours/logger.dart';
import 'package:chaostours/conf/app_routes.dart';
import 'package:chaostours/conf/app_colors.dart';
import 'package:chaostours/view/widget_disposed.dart';
import 'package:chaostours/event_manager.dart';
import 'package:chaostours/cache.dart';
import 'package:chaostours/data_bridge.dart';
import 'package:chaostours/tracking.dart';
import 'package:chaostours/util.dart';
import 'package:chaostours/model/model_alias.dart';
import 'package:chaostours/model/model_task.dart';
import 'package:chaostours/model/model_user.dart';
import 'package:chaostours/model/model_trackpoint.dart';
import 'package:chaostours/trackpoint_data.dart';
//
import 'package:chaostours/view/app_widgets.dart';
import 'package:chaostours/address.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/conf/app_settings.dart';
import 'package:chaostours/screen.dart';

enum _DisplayMode {
  /// shows gps list
  live,

  /// trackpoints from current location
  lastVisited,

  /// recent trackpoints ordered by time
  recentTrackPoints,

  /// display task checkboxes and notes input;
  gps;
}

class WidgetTrackingPage extends StatefulWidget {
  const WidgetTrackingPage({super.key});

  @override
  State<WidgetTrackingPage> createState() => _WidgetTrackingPage();
}

class _WidgetTrackingPage extends State<WidgetTrackingPage> {
  static final Logger logger = Logger.logger<WidgetTrackingPage>();

  _DisplayMode displayMode = _DisplayMode.live;
  static int _bottomBarIndex = 0;

  final DataBridge bridge = DataBridge.instance;

  /// osm
  int circleId = 0;
  final osm.MapController mapController = osm.MapController();

  /// editable fields
  TextEditingController tpNotes =
      TextEditingController(text: DataBridge.instance.trackPointUserNotes);

  void modify() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void deactivate() {
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
  }

  ///
  @override
  void initState() {
    bridge.startService();
    updateAliasList();
    EventManager.listen<EventOnAppTick>(onTick);
    EventManager.listen<EventOnWidgetDisposed>(onOsmGpsPoints);
    EventManager.listen<EventOnCacheLoaded>(onCacheLoaded);
    EventManager.listen<EventOnTrackingStatusChanged>(onTrackingStatusChanged);
    super.initState();
    Future.microtask(() async {
      await bridge.reload();
      await bridge.loadCache();
      if (mounted && displayMode == _DisplayMode.live) {
        setState(() {});
      }
    });
  }

  ///
  @override
  void dispose() {
    EventManager.remove<EventOnAppTick>(onTick);
    EventManager.remove<EventOnWidgetDisposed>(onOsmGpsPoints);
    EventManager.remove<EventOnCacheLoaded>(onCacheLoaded);
    EventManager.remove<EventOnTrackingStatusChanged>(onTrackingStatusChanged);
    super.dispose();
  }

  ///
  Future<void> updateAliasList() async {
    try {
      if (bridge.calcGpsPoints.isNotEmpty) {
        bridge.currentAliasIdList = await Cache.setValue<List<int>>(
            CacheKeys.cacheCurrentAliasIdList,
            ModelAlias.nextAlias(gps: bridge.calcGpsPoints.first)
                .map((e) => e.id)
                .toList());
        if (displayMode == _DisplayMode.live && mounted) {
          setState(() {});
        }
      }
    } catch (e, stk) {
      logger.error('update alias idList: $e', stk);
    }
  }

  void onTrackingStatusChanged(EventOnTrackingStatusChanged e) {
    tpNotes.text = DataBridge.instance.trackPointUserNotes;
    if (displayMode != _DisplayMode.gps) {
      setState(() {});
    }
  }

  ///
  void onCacheLoaded(EventOnCacheLoaded e) {
    logger.log('onCacheLoaded');
    if (displayMode == _DisplayMode.gps) {
      onOsmGpsPoints(EventOnWidgetDisposed());
    }
  }

  ///
  void onTick(EventOnAppTick tick) {
    if (mounted && displayMode != _DisplayMode.gps) {
      setState(() {});
    }
  }

  /// render gpsPoints on OSM Map
  Future<void> onOsmGpsPoints(EventOnWidgetDisposed e) async {
    await mapController.removeAllCircle();

    for (var alias in ModelAlias.getAll()) {
      try {
        mapController.drawCircle(osm.CircleOSM(
          key: "circle${++circleId}",
          centerPoint: osm.GeoPoint(latitude: alias.lat, longitude: alias.lon),
          radius: alias.radius.toDouble(),
          color: AppColors.aliasStatusColor(alias.status),
          strokeWidth: 10,
        ));
      } catch (e, stk) {
        logger.error(e.toString(), stk);
        await Future.delayed(const Duration(seconds: 1));
      }
    }

    /// draw gps points
    try {
      for (var gps in bridge.gpsPoints) {
        mapController.drawCircle(osm.CircleOSM(
          key: "circle${++circleId}",
          centerPoint: osm.GeoPoint(latitude: gps.lat, longitude: gps.lon),
          radius: 2,
          color: AppColors.rawGpsTrackingDot.color,
          strokeWidth: 10,
        ));
      }
      for (var gps in bridge.smoothGpsPoints) {
        mapController.drawCircle(osm.CircleOSM(
          key: "circle${++circleId}",
          centerPoint: osm.GeoPoint(latitude: gps.lat, longitude: gps.lon),
          radius: 3,
          color: AppColors.smoothedGpsTrackingDot.color,
          strokeWidth: 10,
        ));
      }
      for (var gps in bridge.calcGpsPoints) {
        mapController.drawCircle(osm.CircleOSM(
          key: "circle${++circleId}",
          centerPoint: osm.GeoPoint(latitude: gps.lat, longitude: gps.lon),
          radius: 4,
          color: AppColors.calcGpsTrackingDot.color,
          strokeWidth: 10,
        ));
      }
      if (bridge.gpsPoints.isNotEmpty) {
        GPS gps = bridge.trackPointGpsStartStanding ?? bridge.gpsPoints.last;
        mapController.drawCircle(osm.CircleOSM(
          key: "circle${++circleId}",
          centerPoint: osm.GeoPoint(latitude: gps.lat, longitude: gps.lon),
          radius: 5,
          color: AppColors.lastTrackingStatusWithAliasDot.color,
          strokeWidth: 10,
        ));
      }
      if (bridge.trackPointGpsStartStanding != null &&
          bridge.trackingStatus == TrackingStatus.standing &&
          bridge.trackPointAliasIdList.isEmpty) {
        GPS gps = bridge.trackPointGpsStartStanding!;
        mapController.drawCircle(osm.CircleOSM(
          key: "circle${++circleId}",
          centerPoint: osm.GeoPoint(latitude: gps.lat, longitude: gps.lon),
          radius: 5,
          color: AppColors.lastTrackingStatusWithoutAliasDot.color,
          strokeWidth: 10,
        ));
      }
    } catch (e, stk) {
      logger.error(e.toString(), stk);
    }
  }

  ///
  @override
  Widget build(BuildContext context) {
    Widget body = AppWidgets.loading('Waiting for GPS Signal');
    try {
      /// nothing checked at this point
      if (bridge.gpsPoints.isNotEmpty) {
        switch (displayMode) {
          case _DisplayMode.recentTrackPoints:
            body = ListView(
                children: renderRecentTrackPointList(
                    context, ModelTrackPoint.recentTrackPoints()));
            break;

          /// last visited mode
          case _DisplayMode.lastVisited:
            GPS gps = bridge.gpsPoints.first;
            body = ListView(
                children: renderRecentTrackPointList(
                    context, ModelTrackPoint.lastVisited(gps)));
            break;

          /// tasks mode
          case _DisplayMode.gps:
            body = renderOSM(context);
            break;

          /// recent mode
          default:
            if (bridge.trackingStatus == TrackingStatus.moving) {
              body = renderTrackPointMoving(context);
            } else if (bridge.trackingStatus == TrackingStatus.standing) {
              body = renderTrackPointStanding(context);
            } else {
              body = AppWidgets.loading('Waiting for Tracking Status');
            }
        }
      }
    } catch (e, stk) {
      logger.error('::build error: $e', stk);
      body = AppWidgets.loading('Error, please open App Logger for details.');
    }

    return AppWidgets.scaffold(context,
        body: body,
        navBar: bottomNavBar(context),
        appBar: AppBar(title: const Text('Live Tracking')));
  }

  ///
  BottomNavigationBar bottomNavBar(BuildContext context) {
    if (displayMode == _DisplayMode.gps) {
      return BottomNavigationBar(
          currentIndex: 3,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.arrow_back), label: 'Back to Live'),
            BottomNavigationBarItem(
                icon: Icon(Icons.add), label: 'Create Alias'),
            BottomNavigationBarItem(
                icon: Icon(Icons.search), label: 'Lookup Alias'),
            BottomNavigationBarItem(
                icon: Icon(Icons.map), label: 'Google Maps'),
          ],
          onTap: (int id) async {
            switch (id) {
              case 1: // 2.
                await AppWidgets.dialog(contents: <Widget>[
                  const Text('Create Alias here?')
                ], buttons: <Widget>[
                  TextButton(
                    child: const Text('Yes'),
                    onPressed: () async {
                      osm.GeoPoint pos = await mapController
                          .getCurrentPositionAdvancedPositionPicker();
                      GPS gps = GPS(pos.latitude, pos.longitude);
                      String address =
                          (await Address(gps).lookupAddress()).toString();
                      ModelAlias alias = ModelAlias(
                          alias: address,
                          lat: gps.lat,
                          lon: gps.lon,
                          lastVisited: DateTime.now(),
                          radius: AppSettings.distanceTreshold);
                      await ModelAlias.insert(alias);
                      if (mounted) {
                        setState(() {});
                      }
                    },
                  ),
                  TextButton(
                    child: const Text('No'),
                    onPressed: () => Navigator.pop(context),
                  )
                ], context: context);
                break;
              case 2: // 3.

                osm.GeoPoint gps = await mapController
                    .getCurrentPositionAdvancedPositionPicker();
                List<ModelAlias> aliasList =
                    ModelAlias.nextAlias(gps: GPS(gps.latitude, gps.longitude));
                if (aliasList.isNotEmpty) {
                  var id = aliasList.first.id;
                  if (mounted) {
                    Navigator.pushNamed(context, AppRoutes.editAlias.route,
                        arguments: id);
                  }
                } else {
                  Fluttertoast.showToast(msg: 'Here is no Alias');
                }
                break;
              case 3: // 4.
                GPS gps = await GPS.gps();
                osm.GeoPoint gps2 = await mapController
                    .getCurrentPositionAdvancedPositionPicker();
                GPS.launchGoogleMaps(
                    gps.lat, gps.lon, gps2.latitude, gps2.longitude);
                break;
              default: // 1.
                _bottomBarIndex = 0;
                displayMode = _DisplayMode.live;
            }
            _bottomBarIndex = id;
            setState(() {});
            //logger.log('BottomNavBar tapped but no method connected');
          });
    } else {
      return BottomNavigationBar(
          currentIndex: _bottomBarIndex,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.near_me), label: 'Live'),
            BottomNavigationBarItem(
                icon: Icon(Icons.recent_actors), label: 'Lokal'),
            BottomNavigationBarItem(icon: Icon(Icons.timer), label: 'Zeit'),
            BottomNavigationBarItem(icon: Icon(Icons.map), label: 'GPS'),
          ],
          onTap: (int id) {
            switch (id) {
              case 1: // 2.
                displayMode = _DisplayMode.lastVisited;
                break;
              case 2: // 3.
                displayMode = _DisplayMode.recentTrackPoints;
                break;
              case 3: // 4.
                displayMode = _DisplayMode.gps;
                break;
              default: // 5.
                displayMode = _DisplayMode.live;
            }
            _bottomBarIndex = id;
            setState(() {});
            //logger.log('BottomNavBar tapped but no method connected');
          });
    }
  }

  ///
  Widget renderTrackPointMoving(BuildContext context) {
    TrackPointData tp = TrackPointData();
    Location location = Location(bridge.calcGpsPoints.first);
    Widget divider = AppWidgets.divider();
    Widget body =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Center(
          child: Text('\n${AppSettings.weekDays[tp.tStart.weekday]}. den'
              ' ${tp.tStart.day}.${tp.tStart.month}.${tp.tStart.year}')),
      const Center(
          heightFactor: 2,
          child:
              Text('Fahren', style: TextStyle(letterSpacing: 2, fontSize: 20))),
      Center(
          heightFactor: 1.5,
          child: Text('${tp.distanceMoving} km',
              style: const TextStyle(letterSpacing: 2, fontSize: 15))),
      Center(
          heightFactor: 1.5,
          child: Text(
              'Treshold: ${GPS.distanceOverTrackList(bridge.calcGpsPoints).round()}/${AppSettings.distanceTreshold} in ${AppSettings.timeRangeTreshold.inSeconds}s',
              style: const TextStyle(letterSpacing: 2, fontSize: 15))),
      Center(
          child: Text(
              '${tp.tStart.hour}:${tp.tStart.minute} - ${tp.tEnd.hour}:${tp.tEnd.minute}')),
    ]);
    List<Widget> items = [
      divider,
      TextButton(
        style: ButtonStyle(
            padding:
                MaterialStateProperty.all<EdgeInsets>(const EdgeInsets.all(0))),
        child: Text('ALIAS: (${location.status.name})\n${tp.currentAliasText}'),
        onPressed: () async {
          if (bridge.gpsPoints.isNotEmpty) {
            var gps = bridge.gpsPoints.first;
            bridge.currentAliasIdList = await Cache.setValue<List<int>>(
                CacheKeys.cacheCurrentAliasIdList,
                ModelAlias.nextAlias(gps: gps).map((e) => e.id).toList());
            await Cache.reload();
            if (mounted) {
              setState(() {});
            }
          }
        },
      ),
      divider,
      TextButton(
        style: ButtonStyle(
            padding:
                MaterialStateProperty.all<EdgeInsets>(const EdgeInsets.all(0))),
        child: Text('OSM:\n${tp.addressText}', softWrap: true),
        onPressed: () async {
          if (bridge.gpsPoints.isNotEmpty) {
            var gps = bridge.gpsPoints.first;
            var addr = (await Address(gps).lookupAddress()).toString();
            bridge.currentAddress = await Cache.setValue<String>(
                CacheKeys.cacheBackgroundAddress, addr);
            if (mounted) {
              setState(() {});
            }
          }
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
                    bridge.triggeredTrackingStatus == TrackingStatus.standing
                        ? Icons.warning
                        : Icons.warning_amber),
                onPressed: () async {
                  if (bridge.triggeredTrackingStatus !=
                      TrackingStatus.standing) {
                    Fluttertoast.showToast(msg: 'Standing sheduled');
                  }
                  bridge.triggeredTrackingStatus = await Cache.setValue(
                      CacheKeys.cacheTriggerTrackingStatus,
                      TrackingStatus.standing);
                  if (mounted) {
                    setState(() {});
                  }
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
  Widget renderTrackPointStanding(BuildContext context) {
    TrackPointData tp = TrackPointData();
    Widget divider = AppWidgets.divider();
    Location location = Location(bridge.calcGpsPoints.first);
    Widget body =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Center(
          child: Text('\n${AppSettings.weekDays[tp.tStart.weekday]}. den'
              ' ${tp.tStart.day}.${tp.tStart.month}.${tp.tStart.year}')),
      const Center(
          heightFactor: 2,
          child:
              Text('Halten', style: TextStyle(letterSpacing: 2, fontSize: 20))),
      Center(child: Text(tp.durationText)),
      Center(
          child: Text(
              '${tp.tStart.hour}:${tp.tStart.minute} - ${tp.tEnd.hour}:${tp.tEnd.minute}')),
      Center(
          heightFactor: 1.5,
          child: Text(
              'Distanz: ${tp.distanceStanding} / ${tp.standingRadius} m',
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
        child: Text('ALIAS (${location.status.name}):\n${tp.currentAliasText}'),
        onPressed: () async {
          if (bridge.calcGpsPoints.isNotEmpty) {
            bridge.currentAliasIdList = await Cache.setValue<List<int>>(
                CacheKeys.cacheCurrentAliasIdList, location.aliasIdList);
            await Cache.reload();
            if (mounted) {
              setState(() {});
            }
          }
        },
      ),
      divider,

      /// osm
      TextButton(
        style: ButtonStyle(
            alignment: Alignment.centerLeft,
            padding: MaterialStateProperty.all<EdgeInsets>(
                const EdgeInsets.fromLTRB(30, 0, 20, 0))),
        child: Text('OSM:\n${tp.addressText}'),
        onPressed: () async {
          if (bridge.gpsPoints.isNotEmpty) {
            var gps = bridge.gpsPoints.first;
            var addr = (await Address(gps).lookupAddress()).toString();
            bridge.currentAddress = await Cache.setValue<String>(
                CacheKeys.cacheBackgroundAddress, addr);
            if (mounted) {
              setState(() {});
            }
          }
        },
      ),
      divider,
      dropdownTasks(context),
      divider,
      dropdownUser(context),
      divider,
      userNotes(context),
    ];

    return ListView(children: [
      ListTile(
          //contentPadding: EdgeInsets.fromLTRB(0, 0, 0, 0),
          horizontalTitleGap: -30,
          leading: Stack(children: [
            IconButton(
                icon: Icon(
                    bridge.triggeredTrackingStatus == TrackingStatus.moving
                        ? Icons.drive_eta
                        : Icons.drive_eta_outlined),
                onPressed: () async {
                  if (bridge.triggeredTrackingStatus != TrackingStatus.moving) {
                    Fluttertoast.showToast(msg: 'Moving sheduled');
                  }
                  bridge.triggeredTrackingStatus = await Cache.setValue(
                      CacheKeys.cacheTriggerTrackingStatus,
                      TrackingStatus.moving);
                  if (mounted) {
                    setState(() {});
                  }
                }),
            Container(
                padding: const EdgeInsets.fromLTRB(4, 35, 0, 0),
                child: const Text('START', style: TextStyle(fontSize: 10)))
          ]),
          title: body),
      ...items
    ]);
  }

  /// time based recent and location based lastVisited
  List<Widget> renderRecentTrackPointList(
      BuildContext context, List<ModelTrackPoint> tpList) {
    if (tpList.isEmpty) {
      return <Widget>[const Text('\n\nNoch keine Haltepunkte erstellt')];
    }
    List<Widget> listItems = [];
    Widget divider = AppWidgets.divider();
    try {
      for (var tp in tpList) {
        // get task and alias models
        var alias =
            tp.idAlias.map((id) => ModelAlias.getAlias(id).alias).toList();

        var tasks = tp.idTask.map((id) => ModelTask.getTask(id).task).toList();
        var users = tp.idUser.map((id) => ModelUser.getUser(id).user).toList();

        ///

        listItems.add(ListTile(
          title: ListBody(children: [
            Center(
                heightFactor: 2,
                child: alias.isEmpty
                    ? Text('OSM Addr: ${tp.address}')
                    : Text('Alias: - ${alias.join('\n- ')}')),
            Center(child: Text(AppWidgets.timeInfo(tp.timeStart, tp.timeEnd))),
            divider,
            Text(
                'Arbeiten:${tasks.isEmpty ? ' -' : '\n   - ${tasks.join('\n   - ')}'}'),
            divider,
            Text(
                'Personal:${tasks.isEmpty ? ' -' : '\n   - ${users.join('\n   - ')}'}'),
            divider,
            const Text('Notizen:'),
            Text(tp.notes),
          ]),
          leading: IconButton(
              icon: const Icon(Icons.edit_note),
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.editTrackPoint.route,
                    arguments: tp.id);
              }),
        ));
        listItems.add(AppWidgets.divider(color: Colors.black));
      }
    } catch (e, stk) {
      listItems.add(Text(e.toString()));
      logger.error(e.toString(), stk);
    }

    return listItems.reversed.toList();
  }

  /// init OSM Map
  Widget renderOSM(BuildContext context) {
    return osm.OSMFlutter(
      mapIsLoading: const WidgetDisposed(),
      androidHotReloadSupport: true,
      controller: mapController,
      isPicker: true,
      initZoom: 17,
      minZoomLevel: 8,
      maxZoomLevel: 19,
      stepZoom: 1.0,
    );
  }

  ///
  List<Widget> taskCheckboxes(context) {
    var referenceList = DataBridge.instance.trackPointTaskIdList;
    var checkBoxes = <Widget>[];
    for (var model in ModelTask.getAll()) {
      if (!model.deleted) {
        checkBoxes.add(createCheckbox(
            this,
            CheckboxController(
                idReference: model.id,
                referenceList: referenceList,
                deleted: model.deleted,
                title: model.task,
                subtitle: model.notes,
                onToggle: () async {
                  bridge.trackPointTaskIdList = await Cache.setValue<List<int>>(
                      CacheKeys.cacheBackgroundTaskIdList,
                      DataBridge.instance.trackPointTaskIdList);
                  modify();
                })));
      }
    }
    return checkBoxes;
  }

  ///
  List<Widget> userCheckboxes(context) {
    var referenceList = DataBridge.instance.trackPointUserIdList;
    var checkBoxes = <Widget>[];
    for (var model in ModelUser.getAll()) {
      if (!model.deleted) {
        checkBoxes.add(createCheckbox(
            this,
            CheckboxController(
                idReference: model.id,
                referenceList: referenceList,
                deleted: model.deleted,
                title: model.user,
                subtitle: model.notes,
                onToggle: () async {
                  bridge.trackPointUserIdList = await Cache.setValue<List<int>>(
                      CacheKeys.cacheBackgroundUserIdList,
                      DataBridge.instance.trackPointUserIdList);
                  modify();
                })));
      }
    }
    return checkBoxes;
  }

  ///
  bool dropdownUserIsOpen = false;
  Widget dropdownUser(context) {
    /// render selected users

    List<ModelUser> userModels = [];
    for (var model in ModelUser.getAll()) {
      if (DataBridge.instance.trackPointUserIdList.contains(model.id)) {
        userModels.add(model);
      }
    }
    userModels.sort((a, b) => a.sortOrder - b.sortOrder);
    var userList = userModels.map((e) => e.user);
    String users = userList.isNotEmpty ? '\n- ${userList.join('\n- ')}' : ' - ';

    /// dropdown menu botten with selected users
    List<Widget> items = [
      ElevatedButton(
        child: ListTile(
          trailing: const Icon(Icons.menu),
          title: Text(dropdownUserIsOpen ? '' : 'Personal:$users'),
          subtitle: !dropdownUserIsOpen
              ? null
              : Column(children: userCheckboxes(context)),
        ),
        onPressed: () {
          dropdownUserIsOpen = !dropdownUserIsOpen;
          setState(() {});
        },
      ),
    ];

    return ListBody(children: items);
  }

  ///
  bool dropdownTasksIsOpen = false;
  Widget dropdownTasks(context) {
    /// render selected tasks
    List<ModelTask> taskModels = [];
    for (var item in ModelTask.getAll()) {
      if (DataBridge.instance.trackPointTaskIdList.contains(item.id)) {
        taskModels.add(item);
      }
    }
    taskModels.sort((a, b) => a.sortOrder - b.sortOrder);
    var taskList = taskModels.map(
      (e) => e.task,
    );
    String tasks = taskList.isNotEmpty ? '\n- ${taskList.join('\n- ')}' : ' - ';

    /// dropdown menu botten with selected tasks
    List<Widget> items = [
      ElevatedButton(
        child: ListTile(
          trailing: const Icon(Icons.menu),
          title: Text(dropdownTasksIsOpen ? '' : 'Arbeiten:$tasks'),
          subtitle: !dropdownTasksIsOpen
              ? null
              : Column(children: taskCheckboxes(context)),
        ),
        onPressed: () {
          dropdownTasksIsOpen = !dropdownTasksIsOpen;
          setState(() {});
        },
      ),
    ];

    return ListBody(children: items);
  }

  ///
  Widget userNotes(BuildContext context) {
    return Container(
        padding: const EdgeInsets.all(10),
        child: TextField(
            decoration: const InputDecoration(
                label: Text('Notizen'),
                contentPadding: EdgeInsets.all(2),
                border: InputBorder.none),
            //expands: true,
            maxLines: null,
            minLines: 2,
            controller: tpNotes,
            onChanged: (String? s) async {
              bridge.trackPointUserNotes = await Cache.setValue<String>(
                  CacheKeys.cacheBackgroundTrackPointUserNotes, tpNotes.text);
              modify();
            }));
  }
}
