import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart' as osm;
import 'package:fluttertoast/fluttertoast.dart';
//
import 'package:chaostours/logger.dart';
import 'package:chaostours/view/widget_disposed.dart';
import 'package:chaostours/event_manager.dart';
import 'package:chaostours/cache.dart';
import 'package:chaostours/data_bridge.dart';
import 'package:chaostours/background_process/trackpoint.dart';
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
import 'package:chaostours/globals.dart';
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
  List<int> tpTasks = [...DataBridge.instance.trackPointTaskIdList];
  List<int> tpUsers = [...DataBridge.instance.trackPointUserIdList];
  TextEditingController tpNotes =
      TextEditingController(text: DataBridge.instance.trackPointUserNotes);

  void modify() {
    if (mounted) {
      setState(() {});
    }
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
        bridge.trackPointAliasIdList = await Cache.setValue<List<int>>(
            CacheKeys.cacheBackgroundAliasIdList,
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
    tpUsers = [...bridge.trackPointUserIdList];
    tpTasks = [...bridge.trackPointTaskIdList];
    tpNotes.text = bridge.trackPointUserNotes;
  }

  ///
  void onCacheLoaded(EventOnCacheLoaded e) {
    if (displayMode == _DisplayMode.gps) {
      onOsmGpsPoints(EventOnWidgetDisposed());
    }
  }

  ///
  Future<void> onTick(EventOnAppTick tick) async {
    if (displayMode != _DisplayMode.gps) {
      setState(() {});
    }
  }

  /// render gpsPoints on OSM Map
  Future<void> onOsmGpsPoints(EventOnWidgetDisposed e) async {
    await mapController.removeAllCircle();

    for (var alias in ModelAlias.getAll()) {
      try {
        Color color;
        if (alias.status == AliasStatus.public) {
          color = AppColors.aliasPubplic.color;
        } else if (alias.status == AliasStatus.privat) {
          color = AppColors.aliasPrivate.color;
        } else {
          color = AppColors.aliasRestricted.color;
        }

        mapController.drawCircle(osm.CircleOSM(
          key: "circle${++circleId}",
          centerPoint: osm.GeoPoint(latitude: alias.lat, longitude: alias.lon),
          radius: alias.radius.toDouble(),
          color: color,
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
          color: const Color.fromARGB(255, 111, 111, 111),
          strokeWidth: 10,
        ));
      }
      for (var gps in bridge.smoothGpsPoints) {
        mapController.drawCircle(osm.CircleOSM(
          key: "circle${++circleId}",
          centerPoint: osm.GeoPoint(latitude: gps.lat, longitude: gps.lon),
          radius: 3,
          color: Colors.black,
          strokeWidth: 10,
        ));
      }
      for (var gps in bridge.calcGpsPoints) {
        mapController.drawCircle(osm.CircleOSM(
          key: "circle${++circleId}",
          centerPoint: osm.GeoPoint(latitude: gps.lat, longitude: gps.lon),
          radius: 4,
          color: Colors.blue,
          strokeWidth: 10,
        ));
      }
      if (bridge.gpsPoints.isNotEmpty) {
        GPS gps = bridge.trackPointGpsStartStanding ?? bridge.gpsPoints.last;
        mapController.drawCircle(osm.CircleOSM(
          key: "circle${++circleId}",
          centerPoint: osm.GeoPoint(latitude: gps.lat, longitude: gps.lon),
          radius: 5,
          color: Colors.red,
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

    return AppWidgets.scaffold(context,
        body: body, navBar: bottomNavBar(context));
  }

  ///
  BottomNavigationBar bottomNavBar(BuildContext context) {
    if (displayMode == _DisplayMode.gps) {
      return BottomNavigationBar(
          currentIndex: _bottomBarIndex,
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.yellow.color,
          fixedColor: AppColors.black.color,
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.arrow_back), label: 'Live'),
            BottomNavigationBarItem(icon: Icon(Icons.add), label: 'Alias'),
            BottomNavigationBarItem(
                icon: Icon(Icons.search), label: 'Lookup Alias'),
            BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Route'),
          ],
          onTap: (int id) async {
            switch (id) {
              case 1: // 2.
                Navigator.pushNamed(context, AppRoutes.listAlias.route)
                    .then((_) {
                  if (mounted) {
                    setState(() {});
                  }
                });
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
          backgroundColor: AppColors.yellow.color,
          fixedColor: AppColors.black.color,
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
    Widget divider = AppWidgets.divider();
    Screen screen = Screen(context);
    Widget body =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Center(
          child: Text('\n${Globals.weekDays[tp.tStart.weekday]}. den'
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
          child: Text(
              '${tp.tStart.hour}:${tp.tStart.minute} - ${tp.tEnd.hour}:${tp.tEnd.minute}')),
    ]);
    List<Widget> items = [
      divider,
      TextButton(
        style: ButtonStyle(
            padding:
                MaterialStateProperty.all<EdgeInsets>(const EdgeInsets.all(0))),
        child: Text('ALIAS:\n${tp.aliasText}'),
        onPressed: () async {
          if (bridge.gpsPoints.isNotEmpty) {
            var gps = bridge.gpsPoints.first;
            bridge.trackPointAliasIdList = await Cache.setValue<List<int>>(
                CacheKeys.cacheBackgroundAliasIdList,
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
    Widget body =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Center(
          child: Text('\n${Globals.weekDays[tp.tStart.weekday]}. den'
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
        child: Text('ALIAS:\n${tp.aliasText}'),
        onPressed: () async {
          if (bridge.gpsPoints.isNotEmpty) {
            var gps = bridge.gpsPoints.first;
            bridge.trackPointAliasIdList = await Cache.setValue<List<int>>(
                CacheKeys.cacheBackgroundAliasIdList,
                ModelAlias.nextAlias(gps: gps).map((e) => e.id).toList());
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
    var referenceList = tpTasks;
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
                      CacheKeys.cacheBackgroundTaskIdList, tpTasks);
                  modify();
                })));
      }
    }
    return checkBoxes;
  }

  ///
  List<Widget> userCheckboxes(context) {
    var referenceList = tpUsers;
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
                      CacheKeys.cacheBackgroundUserIdList, tpUsers);
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
    List<String> userList = [];
    for (var model in ModelUser.getAll()) {
      if (tpUsers.contains(model.id)) {
        userList.add(model.user);
      }
    }
    String users = userList.isNotEmpty ? '\n- ${userList.join('\n- ')}' : ' - ';

    /// dropdown menu botten with selected users
    List<Widget> items = [
      ElevatedButton(
        child: ListTile(
            trailing: const Icon(Icons.menu), title: Text('Personal:$users')),
        onPressed: () {
          dropdownUserIsOpen = !dropdownUserIsOpen;
          setState(() {});
        },
      ),
      !dropdownUserIsOpen
          ? const SizedBox.shrink()
          : Column(children: userCheckboxes(context))
    ];

    return ListBody(children: items);
  }

  ///
  bool dropdownTasksIsOpen = false;
  Widget dropdownTasks(context) {
    /// render selected tasks
    List<String> taskList = [];
    for (var item in ModelTask.getAll()) {
      if (tpTasks.contains(item.id)) {
        taskList.add(item.task);
      }
    }
    String tasks = taskList.isNotEmpty ? '\n- ${taskList.join('\n- ')}' : ' - ';

    /// dropdown menu botten with selected tasks
    List<Widget> items = [
      ElevatedButton(
        child: ListTile(
            trailing: const Icon(Icons.menu), title: Text('Arbeiten:$tasks')),
        onPressed: () {
          dropdownTasksIsOpen = !dropdownTasksIsOpen;
          setState(() {});
        },
      ),
      !dropdownTasksIsOpen
          ? const SizedBox.shrink()
          : Column(children: taskCheckboxes(context))
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
