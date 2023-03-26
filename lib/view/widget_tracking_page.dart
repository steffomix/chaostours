import 'package:chaostours/main.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:permission_handler/permission_handler.dart';
//
import 'package:chaostours/logger.dart';
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
  /// checkPermissions
  checkPermissions,

  /// no gps signals yet
  waitingForGPS,

  /// shows gps list
  gpsList,

  /// trackpoints from current location
  lastVisited,

  /// recent trackpoints ordered by time
  recentTrackPoints,

  /// display task checkboxes and notes input;
  editTasks;
}

class WidgetTrackingPage extends StatefulWidget {
  const WidgetTrackingPage({super.key});

  @override
  State<WidgetTrackingPage> createState() => _WidgetTrackingPage();
}

class _WidgetTrackingPage extends State<WidgetTrackingPage> {
  static Logger logger = Logger.logger<WidgetTrackingPage>();

  static TrackingPageDisplayMode displayMode =
      TrackingPageDisplayMode.recentTrackPoints;
  static int _bottomBarIndex = 0;

  String currentPermissionCheck = '';

  ///
  /// active trackpoint data
  static TrackingStatus lastStatus = TrackingStatus.none;
  static TrackingStatus currentStatus = TrackingStatus.none;
  static TextEditingController _controller =
      TextEditingController(text: ModelTrackPoint.pendingTrackPoint.notes);

  /// recent or saved trackponts
  static List<GPS> runningTrackPoints = [];

  /// both must be true
  ///

  @override
  void initState() {
    EventManager.listen<EventOnAppTick>(onTick);
    EventManager.listen<EventOnAddressLookup>(onAddressLookup);
    super.initState();
  }

  @override
  void dispose() {
    EventManager.remove<EventOnAppTick>(onTick);
    EventManager.remove<EventOnAddressLookup>(onAddressLookup);
    super.dispose();
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
    // nothing checked at this point
    if (runningTrackPoints.isEmpty) {
      body = AppWidgets.loading('Waiting for GPS Signal');
    } else {
      switch (displayMode) {
        case TrackingPageDisplayMode.recentTrackPoints:
          list = renderRecentTrackPointList(
              context, ModelTrackPoint.recentTrackPoints());

          body = renderListViewBody(context, list);
          break;

        /// tasks mode
        case TrackingPageDisplayMode.editTasks:
          list = renderTasks(context);

          body = renderListViewBody(context, list);
          break;

        /// last visited mode
        case TrackingPageDisplayMode.lastVisited:
          GPS gps = runningTrackPoints.first;
          list = renderRecentTrackPointList(
              context, ModelTrackPoint.lastVisited(gps));

          body = renderListViewBody(context, list);
          break;

        /// recent mode
        default:
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
      }
    }

    return AppWidgets.scaffold(context,
        body: body, navBar: bottomNavBar(context));
  }

  BottomNavigationBar bottomNavBar(BuildContext context) {
    return BottomNavigationBar(
        currentIndex: _bottomBarIndex,
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.yellow.color,
        fixedColor: AppColors.black.color,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'GPS'),
          BottomNavigationBarItem(
              icon: Icon(Icons.recent_actors), label: 'Zul. besucht'),
          BottomNavigationBarItem(icon: Icon(Icons.task), label: 'Aufgaben'),
          BottomNavigationBarItem(icon: Icon(Icons.timer), label: 'Chronol.'),
        ],
        onTap: (int id) {
          switch (id) {
            case 1:
              displayMode = TrackingPageDisplayMode.recentTrackPoints;
              break;
            case 2:
              displayMode = TrackingPageDisplayMode.editTasks;
              break;
            case 3:
              displayMode = TrackingPageDisplayMode.lastVisited;
              break;
            default:
              displayMode = TrackingPageDisplayMode.gpsList;
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
    if (!mounted) {
      return;
    }
    Cache shared = Cache.instance;
    if (shared.gpsPoints.isEmpty) {
      return;
    }

    if (shared.address.isNotEmpty) {
      ModelTrackPoint.pendingAddress = shared.address;
    }

    if (shared.status != TrackingStatus.none) {
      /// get status
      currentStatus = shared.status;
      runningTrackPoints.clear();
      runningTrackPoints.addAll(shared.gpsPoints);
      // update GPS cache
      GPS.lastGps = shared.lastGps;

      /// update pendingTrackPoint
      if (currentStatus == lastStatus) {
        /// update
        ModelTrackPoint.pendingTrackPoint
          ..gps = runningTrackPoints.first
          ..address = ModelTrackPoint.pendingAddress
          ..trackPoints = runningTrackPoints
          ..timeStart = runningTrackPoints.last.time
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
            timeStart: runningTrackPoints.last.time);

        /// add preselected users
        ModelTrackPoint.pendingTrackPoint.idUser
            .addAll(Globals.preselectedUsers);
        lastStatus = currentStatus;
        _controller = TextEditingController(
            text: ModelTrackPoint.pendingTrackPoint.notes);
      }

      /// write to cache user data for background thread
      Cache.instance.activeTrackPoint =
          ModelTrackPoint.pendingTrackPoint.toSharedString();
    }

    setState(() {});
  }

  ModelTrackPoint createTrackPoint(TrackingStatus status) {
    GPS gps = runningTrackPoints.first;
    ModelTrackPoint tp = ModelTrackPoint(
        gps: gps,
        trackPoints: runningTrackPoints,
        idAlias: ModelAlias.nextAlias(gps: gps).map((e) => e.id).toList(),
        timeStart: gps.time);
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
                  : runningTrackPoints.last)
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
            cache
                .saveForeGround(
                    trigger: cache.statusTriggered,
                    trackPoints: cache.trackPointData,
                    activeTp: cache.activeTrackPoint)
                .then((_) {
              setState(() {});
            });
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

  List<Widget> renderTasks(BuildContext context) {
    List<int> referenceList = ModelTrackPoint.pendingTrackPoint.idTask;
    List<Widget> list = [
      Container(
          padding: const EdgeInsets.all(10),
          child: TextField(
              decoration: const InputDecoration(
                  label: Text('Notizen'), contentPadding: EdgeInsets.all(2)),
              //expands: true,
              maxLines: null,
              minLines: 5,
              controller: _controller,
              onChanged: (String? s) =>
                  ModelTrackPoint.pendingTrackPoint.notes = s ?? '')),
      AppWidgets.divider(),
      ...ModelTask.getAll().map((ModelTask task) {
        return editTasks(
            context,
            CheckboxController(
                idReference: task.id,
                referenceList: referenceList,
                title: task.task,
                subtitle: task.notes));
      }).toList()
    ];
    return list;
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
