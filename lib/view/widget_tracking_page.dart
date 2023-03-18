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
import 'package:chaostours/shared.dart';
import 'package:chaostours/model/model_alias.dart';
import 'package:chaostours/model/model_task.dart';
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
    checkPermissions(context);
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

  void checkPermissions(BuildContext context) async {
    Map<String, Permission> pm = {
      'Foreground GPS': Permission.location,
      'Background GPS': Permission.locationAlways,
      //'Ignore Battery Optimizations': Permission.ignoreBatteryOptimizations,

      /// disabled due to always false and no way to grand this permission
      //Permission.storage,
      'External Storage and SDCard': Permission.manageExternalStorage,
      'Notification': Permission.notification,
      'Calendar': Permission.calendar,

      /// user also need to disable not-used app reset
    };
    for (var k in pm.keys) {
      currentPermissionCheck = k;
      setState(() {});
      if ((await pm[k]?.isDenied ?? false) ||
          (await pm[k]?.isPermanentlyDenied ?? false)) {
        Globals.permissionsOk = false;
        Globals.permissionsChecked = true;
        return;
      }
    }
    Globals.permissionsOk = true;
    Globals.permissionsChecked = true;
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
    Widget body =
        AppWidgets.loading('Checking Permission "$currentPermissionCheck".');
    List<Widget> list = [];
    // nothing checked at this point
    if (Globals.permissionsChecked && !Globals.permissionsOk) {
      // navigate
      Navigator.pushNamed(context, AppRoutes.permissions.route).then((_) {
        setState(() {});
      });
    } else if (!Globals.permissionsChecked) {
      displayMode = TrackingPageDisplayMode.checkPermissions;
    } else if (runningTrackPoints.isEmpty) {
      displayMode = TrackingPageDisplayMode.waitingForGPS;
    } else if (Globals.permissionsChecked &&
        Globals.permissionsOk &&
        (displayMode == TrackingPageDisplayMode.checkPermissions ||
            displayMode == TrackingPageDisplayMode.waitingForGPS)) {
      displayMode = TrackingPageDisplayMode.recentTrackPoints;
    }

    switch (displayMode) {
      case TrackingPageDisplayMode.checkPermissions:
        body = AppWidgets.loading('Checking Permissions');
        break;

      case TrackingPageDisplayMode.waitingForGPS:
        body = AppWidgets.loading('Waiting for next GPS Signal');
        break;

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
            (GPS.distanceoverTrackList(runningTrackPoints) / 10).round() / 100;
        list.insert(0, ListTile(leading: Text('Gesamt Distanz: $allDist km')));

        body = renderListViewBody(context, list);
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
    String storage = FileHandler.combinePath(
        FileHandler.storages[Storages.appInternal]!, FileHandler.sharedFile);
    String jsonString = await FileHandler.read(storage);

    Map<String, dynamic> json = {
      JsonKeys.status.name: TrackingStatus.none.name,
      JsonKeys.gpsPoints.name: [],
      JsonKeys.address.name: ''
    };
    try {
      json = jsonDecode(jsonString);
    } catch (e, stk) {
      logger.error(e.toString(), stk);
    }

    Shared shared = Shared(SharedKeys.trackPointUp);
    List<String> sharedList = await shared.loadList() ?? [];
    if (json[JsonKeys.status.name] != TrackingStatus.none.name) {
      try {
        /// get status
        currentStatus =
            TrackingStatus.values.byName(json[JsonKeys.status.name]);
        if ((json[JsonKeys.gpsPoints.name] as List).isNotEmpty) {
          try {
            runningTrackPoints.clear();
            runningTrackPoints.addAll((json[JsonKeys.gpsPoints.name] as List)
                .map((e) => GPS.toSharedObject(e))
                .toList());

            /// update pendingTrackPoint
            if (currentStatus == lastStatus) {
              /// update
              ModelTrackPoint.pendingTrackPoint
                ..gps = runningTrackPoints.first
                ..address = ModelTrackPoint.pendingAddress
                ..trackPoints = runningTrackPoints
                ..timeStart = runningTrackPoints.last.time
                ..timeEnd = runningTrackPoints.first.time
                ..idAlias = ModelAlias.nextAlias(gps: runningTrackPoints.first)
                    .map((e) => e.id)
                    .toList()
                ..idTask = ModelTrackPoint.pendingTrackPoint.idTask
                ..notes = ModelTrackPoint.pendingTrackPoint.notes;
            } else {
              /// update last visited in ModelAlias
              if (currentStatus == TrackingStatus.standing) {
                for (var item
                    in ModelAlias.nextAlias(gps: runningTrackPoints.first)) {
                  if (!item.deleted) {
                    item.lastVisited = DateTime.now();
                  }
                }
                ModelAlias.write();
              }

              /// notify edit page
              await EventManager.fire<EventOnTrackingStatusChanged>(
                  EventOnTrackingStatusChanged(
                      ModelTrackPoint.pendingTrackPoint));

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

            /// write to share user data to background thread
            await Shared(SharedKeys.trackPointDown)
                .saveString(ModelTrackPoint.pendingTrackPoint.toSharedString());
          } catch (e, stk) {
            logger.error(e.toString(), stk);
          }
        }
      } catch (e, stk) {
        logger.error(e.toString(), stk);
      }
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
    try {
      var tp = ModelTrackPoint.pendingTrackPoint;
      var duration = util.timeElapsed(tp.timeStart, tp.timeEnd, false);
      var alias = ModelAlias.nextAlias(
              gps: currentStatus == TrackingStatus.moving
                  ? runningTrackPoints.first
                  : runningTrackPoints.last)
          .map((e) {
        return '- ${e.alias}';
      }).toList();

      var task =
          tp.idTask.map((e) => '- ${ModelTask.getTask(e).task}').toList();
      var notes = tp.notes;

      var sAlias = alias.isEmpty ? ' -' : '\n  -${alias.join('\n  -')}';
      var sTasks = task.isEmpty ? ' -' : '\n  -${task.join('\n  -')}';
      var listBody = ListBody(
        children: [
          Center(
              heightFactor: 2,
              child: Text(
                  currentStatus == TrackingStatus.standing
                      ? '$duration Halten'
                      : '~${(GPS.distanceoverTrackList(runningTrackPoints) / 10).round() / 100}km Fahren',
                  style: const TextStyle(letterSpacing: 2, fontSize: 20))),
          Center(
            heightFactor: 1,
            child: Text(AppWidgets.timeInfo(tp.timeStart, tp.timeEnd)),
          ),
          AppWidgets.divider(),
          Text('OSM: "${ModelTrackPoint.pendingAddress}"', softWrap: true),
          Text('Alias: $sAlias', softWrap: true),
          AppWidgets.divider(),
          Text('Aufgaben: $sTasks', softWrap: true),
          AppWidgets.divider(),
          Text('Notizen: $notes')
        ],
      );

      ///
      /// create widget
      ///
      ///
      return ListTile(
          leading: IconButton(
              icon: const Icon(size: 40, Icons.edit_location),
              onPressed: () {
                ModelTrackPoint.editTrackPoint =
                    ModelTrackPoint.pendingTrackPoint;
                Navigator.pushNamed(context, AppRoutes.editTrackingTasks.route);
              }),
          title: listBody);
    } catch (e, stk) {
      logger.warn(e.toString());
      return Text('$e \n$stk');
    }
  }

  ///
  ///
  ///
  List<Widget> renderRecentTrackPointList(
      BuildContext context, List<ModelTrackPoint> tpList) {
    List<Widget> listItems = [];
    try {
      for (var tp in tpList) {
        if (tp.status == TrackingStatus.standing) {
          var alias =
              tp.idAlias.map((id) => ModelAlias.getAlias(id).alias).toList();

          var tasks =
              tp.idTask.map((id) => ModelTask.getTask(id).task).toList();

          ///

          listItems.add(ListTile(
            title: ListBody(children: [
              Center(
                  heightFactor: 2,
                  child: alias.isEmpty
                      ? Text('OSM Addr: ${tp.address}')
                      : Text('Alias: - ${alias.join('\n- ')}')),
              Center(
                  child: Text(AppWidgets.timeInfo(tp.timeStart, tp.timeEnd))),
              Text(
                  'Aufgaben:${tasks.isEmpty ? ' -' : '\n   - ${tasks.join('\n   - ')}'}'),
              Text('Notizen ${tp.notes}')
            ]),
            leading: IconButton(
                icon: const Icon(Icons.edit_location_outlined),
                onPressed: () {
                  ModelTrackPoint.editTrackPoint = tp;
                  Navigator.pushNamed(
                      context, AppRoutes.editTrackingTasks.route);
                }),
          ));
          listItems.add(AppWidgets.divider(color: Colors.black));
        } else {
          //return <Widget>[Container(child: Text('wrong status'))];
        }
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
