import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart' as osm;
//
import 'package:chaostours/logger.dart';
import 'package:chaostours/view/widget_disposed.dart';
import 'package:chaostours/event_manager.dart';
import 'package:chaostours/cache.dart';
import 'package:chaostours/data_bridge.dart';
import 'package:chaostours/background_process/trackpoint.dart';
import 'package:chaostours/util.dart' as util;
import 'package:chaostours/model/model_alias.dart';
import 'package:chaostours/model/model_task.dart';
import 'package:chaostours/model/model_user.dart';
import 'package:chaostours/model/model_trackpoint.dart';
import 'package:chaostours/checkbox_controller.dart';
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

  /// both must be true
  ///

  @override
  void initState() {
    DataBridge.instance.startService();
    updateAliasList();
    EventManager.listen<EventOnAppTick>(onTick);
    EventManager.listen<EventOnAddressLookup>(onAddressLookup);
    EventManager.listen<EventOnWidgetDisposed>(osmGpsPoints);
    EventManager.listen<EventOnCacheLoaded>(onCacheLoaded);
    super.initState();

    /// force loading background data
    try {
      GPS.gps().then((GPS gps) {
        DataBridge.instance.loadBackground(gps).then((_) {
          if (mounted && displayMode == _DisplayMode.live) {
            setState(() {});
          }
        });
      });
    } catch (e) {
      logger.warn('init state, force loadBackground: $e');
    }
  }

  @override
  void dispose() {
    // make sure bridge updater is running
    bridge.startService();
    EventManager.remove<EventOnAppTick>(onTick);
    EventManager.remove<EventOnAddressLookup>(onAddressLookup);
    EventManager.remove<EventOnWidgetDisposed>(osmGpsPoints);
    EventManager.remove<EventOnCacheLoaded>(onCacheLoaded);
    super.dispose();
  }

  void updateAliasList() {
    try {
      if (displayMode == _DisplayMode.live && bridge.calcGpsPoints.isNotEmpty) {
        bridge.trackPointAliasIdList =
            ModelAlias.nextAlias(gps: bridge.calcGpsPoints.first)
                .map((e) => e.id)
                .toList();
        Cache.setValue<List<int>>(
            CacheKeys.cacheBackgroundAliasIdList, bridge.trackPointAliasIdList);
      }
    } catch (e, stk) {
      logger.error('update alias idList: $e', stk);
    }
  }

  void onCacheLoaded(EventOnCacheLoaded e) {
    if (displayMode == _DisplayMode.gps) {
      osmGpsPoints(EventOnWidgetDisposed());
    }
    updateAliasList();
  }

  Widget renderListViewBody(BuildContext context, List<Widget> list) {
    return ListView(children: [
      renderTrackPoint(context),
      const Divider(
          thickness: 2, indent: 10, endIndent: 10, color: Colors.black),
      ...list
    ]);
  }

  @override
  Widget build(BuildContext context) {
    Widget body = AppWidgets.loading('Waiting for GPS Signal');

    /// nothing checked at this point
    if (bridge.gpsPoints.isEmpty) {
      body = AppWidgets.loading('Waiting for GPS Signal');
    } else {
      switch (displayMode) {
        case _DisplayMode.recentTrackPoints:
          body = ListView(
              children: renderRecentTrackPointList(
                  context, ModelTrackPoint.recentTrackPoints()));
          break;

        /// tasks mode
        case _DisplayMode.gps:
          body = renderOSM(context);
          break;

        /// last visited mode
        case _DisplayMode.lastVisited:
          GPS gps = bridge.gpsPoints.first;
          body = ListView(
              children: renderRecentTrackPointList(
                  context, ModelTrackPoint.lastVisited(gps)));
          break;

        /// recent mode
        default:
          body = renderTrackPoint(context);
      }
    }

    return AppWidgets.scaffold(context,
        body: body, navBar: bottomNavBar(context));
  }

  Widget renderOSM(BuildContext context) {
    return osm.OSMFlutter(
      mapIsLoading: const WidgetDisposed(),
      androidHotReloadSupport: true,
      controller: mapController,
      isPicker: false,
      initZoom: 17,
      minZoomLevel: 8,
      maxZoomLevel: 19,
      stepZoom: 1.0,
    );
  }

  Future<void> osmGpsPoints(EventOnWidgetDisposed e) async {
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

  BottomNavigationBar bottomNavBar(BuildContext context) {
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

  Future<void> onAddressLookup(EventOnAddressLookup event) async {
    if (!mounted || bridge.gpsPoints.isEmpty) {
      return;
    }
    bridge.setAddress(bridge.gpsPoints.first);
  }

  Future<void> onTick(EventOnAppTick tick) async {
    if (displayMode != _DisplayMode.gps) {
      setState(() {});
    }
  }

  Widget renderTrackPoint(BuildContext context) {
    if (bridge.gpsPoints.isEmpty) {
      return AppWidgets.loading('Waiting for GPS from Background...');
    }
    Widget divider = AppWidgets.divider();
    Screen screen = Screen(context);
    DateTime tStart = bridge.trackPointGpslastStatusChange?.time ??
        bridge.gpsPoints.last.time;
    DateTime tEnd = DateTime.now();
    PendingGps gpslastStatusChange =
        bridge.trackPointGpslastStatusChange ?? bridge.gpsPoints.last;
    try {
      var ls = bridge.trackPointGpslastStatusChange;
      String duration =
          ls == null ? '-' : util.timeElapsed(ls.time, tEnd, false);
      List<String> alias =
          ModelAlias.nextAlias(gps: gpslastStatusChange).map((e) {
        return '- ${e.alias}';
      }).toList();
      List<String> users = bridge.trackPointUserIdList.map((id) {
        return '- ${ModelUser.getUser(id).user}';
      }).toList();

      List<String> task = bridge.trackPointTaskIdList
          .map((e) => '- ${ModelTask.getTask(e).task}')
          .toList();
      String notes = bridge.trackPointUserNotes;

      String sAlias = alias.isEmpty ? ' ---' : alias.join('\n');
      String sTasks = task.isEmpty ? ' ---' : task.join('\n');
      String sUsers = users.isEmpty ? ' ---' : users.join('\n');
      Widget listBody = SizedBox(
          width: screen.width - 50,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                  child: Text('\n${Globals.weekDays[tStart.weekday]}. den'
                      ' ${tStart.day}.${tStart.month}.${tStart.year}')),
              Center(
                  heightFactor: 2,
                  child: Text(
                      bridge.trackingStatus == TrackingStatus.standing
                          ? 'Halten'
                          : 'Fahren',
                      style: const TextStyle(letterSpacing: 2, fontSize: 20))),
              Center(
                  heightFactor: 1.5,
                  child: Text(
                      bridge.trackingStatus == TrackingStatus.standing
                          ? duration
                          : '~${(GPS.distanceOverTrackList(bridge.gpsPoints) / 10).round() / 100}km',
                      style: const TextStyle(letterSpacing: 2, fontSize: 15))),
              Center(
                  child: Text(
                      '${tStart.hour}:${tStart.minute} - ${tEnd.hour}:${tEnd.minute}')),
              divider,
              Text('Alias: $sAlias', softWrap: true),
              Text(
                  '\nOSM: "${bridge.currentAddress.isEmpty ? '---' : bridge.currentAddress}"',
                  softWrap: true),
              divider,
              const Text('Personal:'),
              Text(sUsers),
              divider,
              const Text('Aufgaben:'),
              Text(sTasks),
              divider,
              const Text('Notizen:'),
              Text(notes)
            ],
          ));

      var iconEdit = IconButton(
          icon: const Icon(size: 30, Icons.edit_location),
          onPressed: () {
            Navigator.pushNamed(context, AppRoutes.editPendingTrackPoint.route);
          });

      var iconTrigger = IconButton(
          icon: Icon(
              size: 30,
              bridge.statusTriggered
                  ? Icons.drive_eta
                  : Icons.drive_eta_outlined),
          onPressed: () {
            bridge.triggerStatus().then((_) {
              setState(() {});
            });
          });

      var action = bridge.trackingStatus == TrackingStatus.standing
          ? Column(children: [
              const Text('\n'),
              iconTrigger,
              const Text('\n'),
              const Text('\n'),
              const Text('\n'),
              const Text('\n'),
              iconEdit
            ])
          : Column(children: [iconEdit]);

      ///
      /// create widget
      ///
      ///
      return SizedBox(
          height: screen.height,
          width: screen.width,
          child: Row(children: [SizedBox(width: 50, child: action), listBody]));
      /*
      return ListTile(
          leading: SizedBox(width: 55, height: 150, child: action),
          title: listBody);
          */
    } catch (e, stk) {
      logger.warn(e.toString());
      return Text('$e \n$stk');
    }
  }

  ///
  /// this list is used by modes:
  /// time based recent and location based lastVisited
  List<Widget> renderRecentTrackPointList(
      BuildContext context, List<ModelTrackPoint> tpList) {
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
                'Personal:${tasks.isEmpty ? ' -' : '\n   - ${users.join('\n   - ')}'}'),
            divider,
            Text(
                'Aufgaben:${tasks.isEmpty ? ' -' : '\n   - ${tasks.join('\n   - ')}'}'),
            divider,
            const Text('Notizen:'),
            Text(tp.notes),
          ]),
          leading: IconButton(
              icon: const Icon(Icons.edit_location_outlined),
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
}
