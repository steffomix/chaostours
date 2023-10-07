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
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:fluttertoast/fluttertoast.dart';
//
import 'package:chaostours/logger.dart';
import 'package:chaostours/conf/app_routes.dart';
import 'package:chaostours/view/widget_disposed.dart';
import 'package:chaostours/event_manager.dart';
import 'package:chaostours/cache.dart';
import 'package:chaostours/data_bridge.dart';
import 'package:chaostours/tracking.dart';
import 'package:chaostours/util.dart';
import 'package:chaostours/model/model_alias.dart';
import 'package:chaostours/model/model_task.dart';
import 'package:chaostours/model/model_user.dart';
import 'package:chaostours/trackpoint_data.dart';
//
import 'package:chaostours/view/app_widgets.dart';
import 'package:chaostours/address.dart' as addr;
import 'package:chaostours/gps.dart';
import 'package:chaostours/conf/app_settings.dart';
import 'package:chaostours/osm_tools.dart';

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

///
///
///
///

class _WidgetTrackingPage extends State<WidgetTrackingPage> {
  static final Logger logger = Logger.logger<WidgetTrackingPage>();

  _DisplayMode displayMode = _DisplayMode.live;
  static int _bottomBarIndex = 0;

  GPS? _gps;
  TrackPointData? _trackPointData;
  Location? _location;
  bool _initialized = false;

  final DataBridge bridge = DataBridge.instance;

  final List<ModelTask> taskModels = [];
  final List<ModelUser> userModels = [];

  /// osm
  final osmTools = OsmTools();

  double? _mapZoom;
  GeoPoint? _geoPoint;

  /// editable fields
  TextEditingController tpNotes =
      TextEditingController(text: DataBridge.instance.trackPointUserNotes);
  TextEditingController tpSearch = TextEditingController();

  void modify() {
    if (mounted) {
      setState(() {});
    }
  }

  ///
  @override
  void initState() {
    bridge.startService();
    EventManager.listen<EventOnAppTick>(onTick);
    EventManager.listen<EventOnWidgetDisposed>(onOsmReady);
    EventManager.listen<EventOnCacheLoaded>(onCacheLoaded);
    EventManager.listen<EventOnTrackingStatusChanged>(onTrackingStatusChanged);

    ///
    /// initialize
    ///
    reload();

    Future.microtask(() async {
      userModels.clear();
      userModels.addAll(await ModelUser.select());
      taskModels.clear();
      taskModels.addAll(await ModelTask.select());
    });

    super.initState();
  }

  Future<void> reload() async {
    _gps = await GPS.gps();
    await bridge.loadCache();
    await updateAliasList();
    _trackPointData = await TrackPointData.trackPointData();
    _location = await Location.location(_gps!);
    _initialized = true;
    if (mounted && displayMode != _DisplayMode.gps) {
      setState(() {});
    }
  }

  ///
  @override
  void dispose() {
    EventManager.remove<EventOnAppTick>(onTick);
    EventManager.remove<EventOnWidgetDisposed>(onOsmReady);
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
            (await ModelAlias.nextAlias(gps: bridge.calcGpsPoints.first))
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
  Future<void> onCacheLoaded(EventOnCacheLoaded e) async {
    logger.log('onCacheLoaded');
    await reload();
    if (displayMode == _DisplayMode.gps) {
      onOsmReady(EventOnWidgetDisposed());
    }
  }

  ///
  void onTick(EventOnAppTick tick) {
    if (mounted && displayMode != _DisplayMode.gps) {
      setState(() {});
    }
  }

  /// _controller
  MapController? _mapController;
  MapController get mapController {
    return MapController(
        initMapWithUserPosition: const UserTrackingOption(unFollowUser: false));
  }

  OSMOption? _osmOption;
  OSMFlutter? _osmFlutter;
  OSMFlutter get osmFlutter {
    return _osmFlutter ??= OSMFlutter(
      onMapIsReady: (bool ready) {
        _mapController?.removeAllCircle().then(
              (value) => osmTools.renderAlias(mapController),
            );
      },
      osmOption: _osmOption ??= const OSMOption(
        showDefaultInfoWindow: true,
        showZoomController: true,
        isPicker: true,
        zoomOption: ZoomOption(
          initZoom: 17,
          minZoomLevel: 8,
          maxZoomLevel: 19,
          stepZoom: 1.0,
        ),
      ),
      mapIsLoading: AppWidgets.loading('Loading Map'),
      //androidHotReloadSupport: true,
      controller: mapController,
    );
  }

  /// render gpsPoints on OSM Map
  Future<void> onOsmReady(EventOnWidgetDisposed e) async {
    print('#### skip osmReady() ###');
    /*
    osmTools.renderAlias(mapController).then((_) {
      if (_geoPoint != null) {
        var p = GeoPoint(
            latitude: _geoPoint!.latitude, longitude: _geoPoint!.longitude);
        _geoPoint = null;
        Future.delayed(const Duration(milliseconds: 100), () {
          mapController.goToLocation(p);
        });
      }
      if (_mapZoom != null) {
        double zoom = _mapZoom!;
        Future.delayed(const Duration(milliseconds: 100), () {
          mapController.setZoom(zoomLevel: zoom);
          _mapZoom = null;
        });
      }
    });
    */
  }

  ///
  @override
  Widget build(BuildContext context) {
    Widget body = AppWidgets.loading('Waiting for GPS...');
    if (!_initialized) {
      return AppWidgets.scaffold(context,
          body: body, appBar: AppBar(title: const Text('Live Tracking')));
    }
    try {
      /// nothing checked at this point
      if (bridge.gpsPoints.isNotEmpty) {
        switch (displayMode) {
          case _DisplayMode.recentTrackPoints:
            body = AppWidgets.renderTrackPointSearchList(
                context: context,
                textController: tpSearch,
                onUpdate: () {
                  setState(() {});
                });
            break;

          /// last visited mode
          case _DisplayMode.lastVisited:
            GPS gps = bridge.calcGpsPoints.first;
            body = AppWidgets.renderTrackPointSearchList(
                context: context,
                textController: tpSearch,
                onUpdate: () {
                  setState(() {});
                },
                gps: gps);

            break;

          /// tasks mode
          case _DisplayMode.gps:
            body = osmFlutter;
            break;

          /// recent mode
          default:
            if (bridge.trackingStatus == TrackingStatus.moving) {
              body = renderTrackPointMoving();
            } else if (bridge.trackingStatus == TrackingStatus.standing) {
              body = renderTrackPointStanding();
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
                      var geoPoint = await mapController
                          .getCurrentPositionAdvancedPositionPicker();
                      GPS gps = GPS(geoPoint.latitude, geoPoint.longitude);
                      String address =
                          (await addr.Address(gps).lookupAddress()).toString();
                      ModelAlias alias = ModelAlias(
                          title: address,
                          gps: gps,
                          description: '',
                          lastVisited: DateTime.now(),
                          radius: AppSettings.distanceTreshold);
                      await ModelAlias.insert(alias);
                      Future.delayed(const Duration(milliseconds: 100), () {
                        if (mounted) {
                          setState(() {});
                        }
                      });
                    },
                  ),
                  TextButton(
                    child: const Text('No'),
                    onPressed: () => Navigator.pop(context),
                  )
                ], context: context);

                break;
              case 2: // 3.

                _geoPoint = await mapController
                    .getCurrentPositionAdvancedPositionPicker();
                _mapZoom = await mapController.getZoom();
                List<ModelAlias> aliasList = await ModelAlias.nextAlias(
                    gps: GPS(_geoPoint!.latitude, _geoPoint!.longitude));
                if (aliasList.isNotEmpty) {
                  if (mounted) {
                    Navigator.pushNamed(context, AppRoutes.editAlias.route,
                            arguments: aliasList.first.id)
                        .then(
                      (value) {
                        if (mounted) {
                          setState(() {});
                        }
                      },
                    );
                  }
                } else {
                  Fluttertoast.showToast(msg: 'Here is no Alias');
                }
                break;
              case 3: // 4.
                GPS gps = await GPS.gps();
                var geoPoint = await mapController
                    .getCurrentPositionAdvancedPositionPicker();
                GPS.launchGoogleMaps(
                    gps.lat, gps.lon, geoPoint.latitude, geoPoint.longitude);
                break;
              default: // 1.
                _bottomBarIndex = 0;
                displayMode = _DisplayMode.live;
            }
            _bottomBarIndex = id;
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
  Widget renderTrackPointMoving() {
    if (_trackPointData == null) {
      return AppWidgets.loading('Waiting for Trackpoint Data');
    }
    TrackPointData tp = _trackPointData!;
    if (_location == null) {
      return AppWidgets.loading('Waiting for GPS');
    }
    Location location = _location!;
    Widget divider = AppWidgets.divider();
    Widget body =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Center(
          child: Text('\n${AppSettings.weekDays[tp.timeStart.weekday]}. den'
              ' ${tp.timeStart.day}.${tp.timeStart.month}.${tp.timeStart.year}')),
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
              '${tp.timeStart.hour}:${tp.timeStart.minute} - ${tp.timeEnd.hour}:${tp.timeEnd.minute}')),
    ]);
    List<Widget> items = [
      divider,
      TextButton(
        style: ButtonStyle(
            padding:
                MaterialStateProperty.all<EdgeInsets>(const EdgeInsets.all(0))),
        child: Text(
            'ALIAS: (${location.visibility.name})\n${tp.currentAliasText}'),
        onPressed: () async {
          if (bridge.gpsPoints.isNotEmpty) {
            var gps = bridge.gpsPoints.first;
            bridge.currentAliasIdList = await Cache.setValue<List<int>>(
                CacheKeys.cacheCurrentAliasIdList,
                (await ModelAlias.nextAlias(gps: gps))
                    .map((e) => e.id)
                    .toList());
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
            var address = (await addr.Address(gps).lookupAddress()).toString();
            bridge.currentAddress = await Cache.setValue<String>(
                CacheKeys.cacheBackgroundAddress, address);
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
  Widget renderTrackPointStanding() {
    if (_trackPointData == null) {
      return AppWidgets.loading('Waiting for Trackpoint Data');
    }
    TrackPointData tp = _trackPointData!;
    if (_location == null) {
      return AppWidgets.loading('Waiting for GPS');
    }
    Location location = _location!;
    Widget divider = AppWidgets.divider();
    Widget body =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Center(
          child: Text('\n${AppSettings.weekDays[tp.timeStart.weekday]}. den'
              ' ${tp.timeStart.day}.${tp.timeStart.month}.${tp.timeStart.year}')),
      const Center(
          heightFactor: 2,
          child:
              Text('Halten', style: TextStyle(letterSpacing: 2, fontSize: 20))),
      Center(child: Text(tp.durationText)),
      Center(
          child: Text(
              '${tp.timeStart.hour}:${tp.timeStart.minute} - ${tp.timeEnd.hour}:${tp.timeEnd.minute}')),
      Center(
          heightFactor: 1.5,
          child: Text('Distanz: ${tp.distanceStanding} / ${tp.radius} m',
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
        child: Text(
            'ALIAS (${location.visibility.name}):\n${tp.currentAliasText}'),
        onPressed: () async {
          if (bridge.calcGpsPoints.isNotEmpty) {
            bridge.currentAliasIdList = await Cache.setValue<List<int>>(
                CacheKeys.cacheCurrentAliasIdList, location.aliasIds);
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
            var address = (await addr.Address(gps).lookupAddress()).toString();
            bridge.currentAddress = await Cache.setValue<String>(
                CacheKeys.cacheBackgroundAddress, address);
            if (mounted) {
              setState(() {});
            }
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

  ///
  List<Widget> taskCheckboxes() {
    var referenceList = DataBridge.instance.trackPointTaskIdList;
    var checkBoxes = <Widget>[];
    for (var model in taskModels) {
      if (model.isActive) {
        checkBoxes.add(createCheckbox(
            this,
            CheckboxController(
                idReference: model.id,
                referenceList: referenceList,
                isActive: model.isActive,
                title: model.title,
                subtitle: model.description,
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
  List<Widget> userCheckboxes() {
    var referenceList = DataBridge.instance.trackPointUserIdList;
    var checkBoxes = <Widget>[];
    for (var model in userModels) {
      if (model.isActive) {
        checkBoxes.add(createCheckbox(
            this,
            CheckboxController(
                idReference: model.id,
                referenceList: referenceList,
                isActive: model.isActive,
                title: model.title,
                subtitle: model.description,
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
  Widget dropdownUser() {
    /// render selected users

    List<ModelUser> userModels = [];
    for (var model in userModels) {
      if (DataBridge.instance.trackPointUserIdList.contains(model.id)) {
        userModels.add(model);
      }
    }
    userModels.sort((a, b) => a.sortOrder - b.sortOrder);
    var userList = userModels.map((e) => e.title);
    String users = userList.isNotEmpty ? '\n- ${userList.join('\n- ')}' : ' - ';

    /// dropdown menu botten with selected users
    List<Widget> items = [
      ElevatedButton(
        child: ListTile(
          trailing: const Icon(Icons.menu),
          title: Text(dropdownUserIsOpen ? '' : 'Personal:$users'),
          subtitle:
              !dropdownUserIsOpen ? null : Column(children: userCheckboxes()),
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
  Widget dropdownTasks() {
    /// render selected tasks
    List<ModelTask> taskModels = [];
    for (var item in taskModels) {
      if (DataBridge.instance.trackPointTaskIdList.contains(item.id)) {
        taskModels.add(item);
      }
    }
    taskModels.sort((a, b) => a.sortOrder - b.sortOrder);
    var taskList = taskModels.map(
      (e) => e.title,
    );
    String tasks = taskList.isNotEmpty ? '\n- ${taskList.join('\n- ')}' : ' - ';

    /// dropdown menu botten with selected tasks
    List<Widget> items = [
      ElevatedButton(
        child: ListTile(
          trailing: const Icon(Icons.menu),
          title: Text(dropdownTasksIsOpen ? '' : 'Arbeiten:$tasks'),
          subtitle:
              !dropdownTasksIsOpen ? null : Column(children: taskCheckboxes()),
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
  Widget userNotes() {
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
