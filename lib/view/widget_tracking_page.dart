import 'package:chaostours/main.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart' as osm;
//
import 'package:chaostours/logger.dart';
import 'package:chaostours/view/widget_disposed.dart';
import 'package:chaostours/event_manager.dart';
import 'package:chaostours/file_handler.dart';
import 'package:chaostours/background_process/trackpoint.dart';
import 'package:chaostours/util.dart' as util;
import 'package:chaostours/cache.dart';
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

enum TrackingPageDisplayMode {
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
  static Logger logger = Logger.logger<WidgetTrackingPage>();

  TrackingPageDisplayMode displayMode = TrackingPageDisplayMode.live;
  static int _bottomBarIndex = 0;

  String currentPermissionCheck = '';

  ///
  /// active trackpoint data
  static TrackingStatus lastStatus = TrackingStatus.none;
  static TrackingStatus currentStatus = TrackingStatus.none;

  /// edit trackpoint notes controller
  static TextEditingController _controller =
      TextEditingController(text: ModelTrackPoint.pendingTrackPoint.notes);

  /// osm
  int circleId = 0;
  osm.MapController mapController = osm.MapController();

  /// recent or saved trackponts
  static List<GPS> runningTrackPoints = [];

  /// both must be true
  ///

  @override
  void initState() {
    EventManager.listen<EventOnAppTick>(onTick);
    EventManager.listen<EventOnAddressLookup>(onAddressLookup);
    EventManager.listen<EventOnWidgetDisposed>(osmGpsPoints);
    EventManager.listen<EventOnCacheLoaded>(onCacheLoaded);
    super.initState();

    /// force loading background data
    try {
      GPS.gps().then((GPS gps) {
        Cache.instance.loadBackground(gps).then((_) {
          setState(() {});
        });
      });
    } catch (e) {
      logger.warn('osm init no gps: $e');
    }
  }

  @override
  void dispose() {
    EventManager.remove<EventOnAppTick>(onTick);
    EventManager.remove<EventOnAddressLookup>(onAddressLookup);
    EventManager.remove<EventOnWidgetDisposed>(osmGpsPoints);
    EventManager.remove<EventOnCacheLoaded>(onCacheLoaded);
    super.dispose();
  }

  void onCacheLoaded(EventOnCacheLoaded e) {
    if (displayMode == TrackingPageDisplayMode.gps) {
      osmGpsPoints(EventOnWidgetDisposed());
    }
  }

  Widget renderListViewBody(BuildContext context, List<Widget> list) {
    return ListView(children: [
      renderActiveTrackPoint(context),
      const Divider(
          thickness: 2, indent: 10, endIndent: 10, color: Colors.black),
      ...list
    ]);
  }

  @override
  Widget build(BuildContext context) {
    Widget body = AppWidgets.loading('Waiting for GPS Signal');
    List<Widget> list = [];

    /// nothing checked at this point
    if (runningTrackPoints.isEmpty) {
      body = AppWidgets.loading('Waiting for GPS Signal');
    } else {
      switch (displayMode) {
        case TrackingPageDisplayMode.recentTrackPoints:
          body = ListView(
              children: renderRecentTrackPointList(
                  context, ModelTrackPoint.recentTrackPoints()));
          break;

        /// tasks mode
        case TrackingPageDisplayMode.gps:
          body = renderOSM(context);
          break;

        /// last visited mode
        case TrackingPageDisplayMode.lastVisited:
          GPS gps = runningTrackPoints.first;
          body = ListView(
              children: renderRecentTrackPointList(
                  context, ModelTrackPoint.lastVisited(gps)));
          break;

        /// recent mode
        default:
          body = renderActiveTrackPoint(context);
        /*
          GPS lastPoint = runningTrackPoints.first;
          list = runningTrackPoints.map((gps) {
            int h = gps.time.hour;
            int m = gps.time.minute;
            int s = gps.time.second;
            double lat = gps.lat;
            double lon = gps.lon;
            double dist = (GPS.distance(lastPoint, gps) / 10).round() / 100;
            lastPoint = gps;
            return ListTile(
              title: Text('$h:$m:$s - $dist km'),
              subtitle: Text('$lat,$lon'),
              leading: const Icon(Icons.map),
            );
          }).toList();
          double allDist =
              (GPS.distanceoverTrackList(runningTrackPoints) / 10).round() /
                  100;
          list.insert(
              0, ListTile(leading: Text('Gesamt Distanz: $allDist km')));

          body = renderListViewBody(context, list);
          */
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

    Cache cache = Cache.instance;

    /// draw gps points
    try {
      for (var gps in cache.gpsPoints) {
        mapController.drawCircle(osm.CircleOSM(
          key: "circle${++circleId}",
          centerPoint: osm.GeoPoint(latitude: gps.lat, longitude: gps.lon),
          radius: 2,
          color: const Color.fromARGB(255, 80, 80, 80),
          strokeWidth: 10,
        ));
      }
      for (var gps in cache.smoothGpsPoints) {
        mapController.drawCircle(osm.CircleOSM(
          key: "circle${++circleId}",
          centerPoint: osm.GeoPoint(latitude: gps.lat, longitude: gps.lon),
          radius: 3,
          color: Colors.black,
          strokeWidth: 10,
        ));
      }
      for (var gps in cache.calcGpsPoints) {
        mapController.drawCircle(osm.CircleOSM(
          key: "circle${++circleId}",
          centerPoint: osm.GeoPoint(latitude: gps.lat, longitude: gps.lon),
          radius: 4,
          color: Colors.blue,
          strokeWidth: 10,
        ));
      }
    } catch (e, stk) {
      logger.error(e.toString(), stk);
    }
    GPS gps = cache.lastStatusChange ?? cache.gpsPoints.last;
    mapController.drawCircle(osm.CircleOSM(
      key: "circle${++circleId}",
      centerPoint: osm.GeoPoint(latitude: gps.lat, longitude: gps.lon),
      radius: 5,
      color: Colors.red,
      strokeWidth: 10,
    ));
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
              displayMode = TrackingPageDisplayMode.lastVisited;
              break;
            case 2: // 3.
              displayMode = TrackingPageDisplayMode.recentTrackPoints;
              break;
            case 3: // 4.
              displayMode = TrackingPageDisplayMode.gps;
              break;
            default: // 5.
              displayMode = TrackingPageDisplayMode.live;
          }
          _bottomBarIndex = id;
          setState(() {});
          //logger.log('BottomNavBar tapped but no method connected');
        });
  }

  Future<void> onAddressLookup(EventOnAddressLookup event) async {
    if (!mounted) {
      return;
    }
    ModelTrackPoint.pendingAddress =
        (await Address(runningTrackPoints.first).lookupAddress()).toString();
  }

  Future<void> onTick(EventOnAppTick tick) async {
    if (!mounted || displayMode == TrackingPageDisplayMode.gps) {
      return;
    }
    Cache cache = Cache.instance;
    if (cache.gpsPoints.isEmpty) {
      return;
    }

    if (cache.address.isNotEmpty) {
      ModelTrackPoint.pendingAddress = cache.address;
    }

    if (cache.status != TrackingStatus.none) {
      /// get status
      currentStatus = cache.status;
      runningTrackPoints.clear();
      runningTrackPoints.addAll(cache.gpsPoints);
      // update GPS cache
      GPS.lastGps = cache.lastGps;

      /// update pendingTrackPoint
      if (currentStatus == lastStatus) {
        /// update
        ModelTrackPoint.pendingTrackPoint
          ..gps = runningTrackPoints.first
          ..address = ModelTrackPoint.pendingAddress
          ..trackPoints = runningTrackPoints
          ..timeStart =
              cache.lastStatusChange?.time ?? runningTrackPoints.last.time
          ..timeEnd = DateTime.now()
          ..idAlias = ModelAlias.nextAlias(gps: runningTrackPoints.first)
              .map((e) => e.id)
              .toList()
          ..idTask = ModelTrackPoint.pendingTrackPoint.idTask
          ..notes = ModelTrackPoint.pendingTrackPoint.notes;
      } else {
        /// status has changed
        /// we need to reload ModelTrackPoint and ModelAlias
        ModelTrackPoint.open();
        ModelAlias.open();

        /// notify edit page
        await EventManager.fire<EventOnTrackingStatusChanged>(
            EventOnTrackingStatusChanged(ModelTrackPoint.pendingTrackPoint));

        /// create new Trackpoint
        ModelTrackPoint.pendingTrackPoint = ModelTrackPoint(
            gps: runningTrackPoints.last,
            trackPoints: runningTrackPoints,
            idAlias: <int>[],
            timeStart:
                cache.lastStatusChange?.time ?? runningTrackPoints.last.time);

        /// add preselected users
        ModelTrackPoint.pendingTrackPoint.idUser
            .addAll(Globals.preselectedUsers);
        lastStatus = currentStatus;
        /*
        _controller = TextEditingController(
            text: ModelTrackPoint.pendingTrackPoint.notes);
        */
        _controller.value =
            TextEditingValue(text: ModelTrackPoint.pendingTrackPoint.notes);
      }

      /// write to cache user data for background thread
      Cache.instance.pendingTrackPoint = ModelTrackPoint.pendingTrackPoint;
    }

    setState(() {});
  }

  ModelTrackPoint createTrackPoint(TrackingStatus status) {
    GPS gps = runningTrackPoints.first;
    ModelTrackPoint tp = ModelTrackPoint(
        gps: gps,
        trackPoints: runningTrackPoints,
        idAlias: ModelAlias.nextAlias(gps: gps).map((e) => e.id).toList(),
        timeStart: Cache.instance.lastStatusChange?.time ??
            runningTrackPoints.last.time);
    tp.status = status;
    tp.timeEnd = runningTrackPoints.last.time;
    tp.idTask = ModelTrackPoint.pendingTrackPoint.idTask;
    tp.notes = ModelTrackPoint.pendingTrackPoint.notes;
    return tp;
  }

  Widget renderActiveTrackPoint(BuildContext context) {
    Screen screen = Screen(context);
    try {
      ModelTrackPoint tp = ModelTrackPoint.pendingTrackPoint;
      String duration = util.timeElapsed(tp.timeStart, tp.timeEnd, false);
      List<String> alias = ModelAlias.nextAlias(
              gps: currentStatus == TrackingStatus.moving
                  ? runningTrackPoints.first
                  : Cache.instance.lastStatusChange ?? runningTrackPoints.last)
          .map((e) {
        return '- ${e.alias}';
      }).toList();
      List<String> users = tp.idUser.map((id) {
        return '- ${ModelUser.getUser(id).user}';
      }).toList();

      List<String> task =
          tp.idTask.map((e) => '- ${ModelTask.getTask(e).task}').toList();
      String notes = tp.notes;

      String sAlias = alias.isEmpty ? ' ---' : '\n  ${alias.join('\n')}';
      String sTasks = task.isEmpty ? ' ---' : '\n  ${task.join('\n')}';
      String sUsers = users.isEmpty ? ' ---' : '\n  ${users.join('\n')}';
      Widget listBody = SizedBox(
          width: screen.width - 50,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                  child: Text('\n${Globals.weekDays[tp.timeStart.weekday]}. den'
                      ' ${tp.timeStart.day}.${tp.timeStart.month}.${tp.timeStart.year}')),
              Center(
                  heightFactor: 2,
                  child: Text(
                      currentStatus == TrackingStatus.standing
                          ? 'Halten'
                          : 'Fahren',
                      style: const TextStyle(letterSpacing: 2, fontSize: 20))),
              Center(
                  heightFactor: 1.5,
                  child: Text(
                      currentStatus == TrackingStatus.standing
                          ? duration
                          : '~${(GPS.distanceoverTrackList(runningTrackPoints) / 10).round() / 100}km',
                      style: const TextStyle(letterSpacing: 2, fontSize: 15))),
              Center(
                  child: Text(
                      '${tp.timeStart.hour}:${tp.timeStart.minute} - ${tp.timeEnd.hour}:${tp.timeEnd.minute}')),
              AppWidgets.divider(),
              Text('Alias: $sAlias', softWrap: true),
              Text(
                  '\nOSM: "${ModelTrackPoint.pendingAddress.trim().isEmpty ? '---' : ModelTrackPoint.pendingAddress}"',
                  softWrap: true),
              AppWidgets.divider(),
              Text('Personal: $sUsers'),
              Text('\nAufgaben: $sTasks', softWrap: true),
              AppWidgets.divider(),
              Text('Notizen: $notes')
            ],
          ));

      var iconEdit = IconButton(
          icon: const Icon(size: 30, Icons.edit_location),
          onPressed: () {
            ModelTrackPoint.editTrackPoint = ModelTrackPoint.pendingTrackPoint;
            Navigator.pushNamed(context, AppRoutes.editTrackingTasks.route);
          });

      var iconTrigger = IconButton(
          icon: Icon(
              size: 30,
              Cache.instance.statusTriggered
                  ? Icons.drive_eta
                  : Icons.drive_eta_outlined),
          onPressed: () {
            Cache cache = Cache.instance;
            cache.triggerStatus();
            setState(() {});
          });

      var action = currentStatus == TrackingStatus.standing
          ? Column(children: [
              const Text('\n'),
              iconEdit,
              const Text('\n'),
              AppWidgets.divider(),
              const Text('\n'),
              iconTrigger
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
    try {
      for (var tp in tpList) {
        // get task and alias models
        var alias =
            tp.idAlias.map((id) => ModelAlias.getAlias(id).alias).toList();

        var tasks = tp.idTask.map((id) => ModelTask.getTask(id).task).toList();

        ///

        listItems.add(ListTile(
          title: ListBody(children: [
            Center(
                heightFactor: 2,
                child: alias.isEmpty
                    ? Text('OSM Addr: ${tp.address}')
                    : Text('Alias: - ${alias.join('\n- ')}')),
            Center(child: Text(AppWidgets.timeInfo(tp.timeStart, tp.timeEnd))),
            Text(
                'Aufgaben:${tasks.isEmpty ? ' -' : '\n   - ${tasks.join('\n   - ')}'}'),
            Text('Notizen ${tp.notes}')
          ]),
          leading: IconButton(
              icon: const Icon(Icons.edit_location_outlined),
              onPressed: () {
                ModelTrackPoint.editTrackPoint = tp;
                Navigator.pushNamed(context, AppRoutes.editTrackingTasks.route);
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

  Widget editTasks(BuildContext context, CheckboxController model) {
    TextStyle style = model.enabled
        ? const TextStyle(color: Colors.black)
        : const TextStyle(color: Colors.grey);
    return ListTile(
      subtitle:
          Text(model.subtitle, style: const TextStyle(color: Colors.grey)),
      title: Text(
        model.title,
        style: style,
      ),
      leading: Checkbox(
        value: model.checked,
        onChanged: (_) {
          setState(
            () {
              model.handler()?.call();
            },
          );
        },
      ),
      onTap: () {
        setState(
          () {
            model.handler()?.call();
          },
        );
      },
    );
  }
}
