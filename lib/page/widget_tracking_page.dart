import 'package:chaostours/main.dart';
import 'package:flutter/material.dart';
//
import 'package:chaostours/logger.dart';
import 'package:chaostours/event_manager.dart';
import 'package:chaostours/trackpoint.dart';
import 'package:chaostours/util.dart' as util;
import 'package:chaostours/shared/shared.dart';
import 'package:chaostours/model/model_alias.dart';
import 'package:chaostours/model/model_task.dart';
import 'package:chaostours/model/model_trackpoint.dart';
import 'package:chaostours/model/model_checkbox.dart';
//
import 'package:chaostours/widget/widgets.dart';
import 'package:chaostours/address.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/screen.dart';

enum TrackingPageDisplayMode {
  /// trackpoints from current location
  lastVisited,

  /// recent trackpoints ordered by time
  recent,

  /// display task checkboxes and notes input;
  tasks;
}

class WidgetTrackingPage extends StatefulWidget {
  const WidgetTrackingPage({super.key});

  @override
  State<WidgetTrackingPage> createState() => _WidgetTrackingPage();
}

class _WidgetTrackingPage extends State<WidgetTrackingPage> {
  static Logger logger = Logger.logger<WidgetTrackingPage>();

  static TrackingPageDisplayMode displayMode = TrackingPageDisplayMode.recent;
  static int _bottomBarIndex = 0;

  ///
  /// active trackpoint data
  static TrackingStatus lastStatus = TrackingStatus.none;
  static TrackingStatus currentStatus = TrackingStatus.none;
  static TextEditingController _controller =
      TextEditingController(text: ModelTrackPoint.pendingTrackPoint.notes);

  /// recent or saved trackponts
  static List<GPS> runningTrackPoints = [];

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

  @override
  Widget build(BuildContext context) {
    List<Widget> list = [];
    switch (displayMode) {

      /// tasks mode
      case TrackingPageDisplayMode.tasks:
        list.addAll(renderTasks(context));
        break;

      /// last visited mode
      case TrackingPageDisplayMode.lastVisited:
        if (runningTrackPoints.isNotEmpty) {
          GPS gps = runningTrackPoints.first;
          list =
              renderTrackPointList(context, ModelTrackPoint.lastVisited(gps));
        }
        break;

      /// recent mode
      default:
        list =
            renderTrackPointList(context, ModelTrackPoint.recentTrackPoints());
    }

    Widget body = ListView(children: [
      renderActiveTrackPoint(context),
      const Divider(
          thickness: 2, indent: 10, endIndent: 10, color: Colors.black),
      ...list
    ]);

    return AppWidgets.scaffold(context,
        body: body, navBar: bottomNavBar(context));
  }

  BottomNavigationBar bottomNavBar(BuildContext context) {
    return BottomNavigationBar(
        currentIndex: _bottomBarIndex,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.recent_actors), label: 'Zuletzt besucht'),
          BottomNavigationBarItem(icon: Icon(Icons.task), label: 'Aufgaben'),
          BottomNavigationBarItem(
              icon: Icon(Icons.timer), label: 'Chronologisch'),
        ],
        onTap: (int id) {
          switch (id) {
            case 1:
              displayMode = TrackingPageDisplayMode.tasks;
              break;
            case 2:
              displayMode = TrackingPageDisplayMode.lastVisited;
              break;
            default:
              displayMode = TrackingPageDisplayMode.recent;
          }
          _bottomBarIndex = id;
          setState(() {});
          //logger.log('BottomNavBar tapped but no method connected');
        });
  }

  Future<void> onAddressLookup(EventOnAddressLookup event) async {
    ModelTrackPoint.pendingAddress =
        (await Address(runningTrackPoints.first).lookupAddress()).toString();
  }

  Future<void> onTick(EventOnAppTick tick) async {
    Shared shared = Shared(SharedKeys.trackPointUp);
    List<String> sharedList = await shared.loadList() ?? [];
    if (sharedList.isNotEmpty) {
      try {
        /// get status
        currentStatus = TrackingStatus.values.byName(sharedList[0]);
        if (sharedList.length > 1) {
          sharedList.removeAt(0);
          try {
            runningTrackPoints.clear();
            for (var row in sharedList) {
              runningTrackPoints.add(GPS.toSharedObject(row));
            }

            /// update pendingTrackPoint
            if (currentStatus == lastStatus) {
              /// update
              ModelTrackPoint.pendingTrackPoint
                ..gps = runningTrackPoints.first
                ..address = ModelTrackPoint.pendingAddress
                ..trackPoints = runningTrackPoints
                ..timeStart = runningTrackPoints.last.time
                ..timeEnd = runningTrackPoints.first.time
                ..idAlias = ModelAlias.nextAlias(runningTrackPoints.first)
                    .map((e) => e.id)
                    .toList()
                ..idTask = ModelTrackPoint.pendingTrackPoint.idTask
                ..notes = ModelTrackPoint.pendingTrackPoint.notes;
            } else {
              await EventManager.fire<EventOnTrackingStatusChanged>(
                  EventOnTrackingStatusChanged(
                      ModelTrackPoint.pendingTrackPoint));
              ModelTrackPoint.pendingTrackPoint = ModelTrackPoint(
                  gps: runningTrackPoints.last,
                  trackPoints: runningTrackPoints,
                  idAlias: <int>[],
                  timeStart: runningTrackPoints.last.time);
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
        idAlias: ModelAlias.nextAlias(gps).map((e) => e.id).toList(),
        timeStart: gps.time);
    tp.status = status;
    tp.timeEnd = runningTrackPoints.last.time;
    tp.idTask = ModelTrackPoint.pendingTrackPoint.idTask;
    tp.notes = ModelTrackPoint.pendingTrackPoint.notes;
    return tp;
  }

  Widget activeTrackPointInfo(
      {required TrackingStatus status,
      required DateTime timeStart,
      required DateTime timeEnd,
      required Duration duration,
      required List<String> alias,
      required List<String> task,
      required String notes}) {
    String time = '${timeStart.hour}:${timeStart.minute}';
    String sAlias = alias.isEmpty ? ' -' : '\n  -${alias.join('\n  -')}';
    String sTasks = task.isEmpty ? ' -' : '\n  -${task.join('\n  -')}';
    return ListBody(
      children: [
        Center(
            heightFactor: 2,
            child: Text(
                status == TrackingStatus.standing
                    ? '$time Halten'
                    : '$time Fahren',
                style: const TextStyle(letterSpacing: 2, fontSize: 20))),
        Center(
            heightFactor: 1,
            child: Text(
                '(${util.timeElapsed(timeStart, timeEnd, false)}) ${runningTrackPoints.length}',
                softWrap: true)),
        AppWidgets.divider(),
        Text('OSM: "${ModelTrackPoint.pendingAddress}"', softWrap: true),
        Text('Alias: $sAlias', softWrap: true),
        AppWidgets.divider(),
        Text('Aufgaben: $sTasks', softWrap: true),
        AppWidgets.divider(),
        Text('Notizen: $notes')
      ],
    );
  }

  Widget recentTrackPointInfo(ModelTrackPoint tp) {
    List<String> alias =
        tp.idAlias.map((id) => ModelAlias.getAlias(id).alias).toList();

    List<String> tasks =
        tp.idTask.map((id) => ModelTask.getTask(id).task).toList();
    String duration = util.timeElapsed(tp.timeStart, tp.timeEnd);

    ///
    return ListBody(children: [
      Center(
          heightFactor: 2,
          child: alias.isEmpty
              ? Text('OSM Addr: ${tp.address}')
              : Text('Alias: - ${alias.join('\n- ')}')),
      Center(child: Text(duration)),
      Text(
          'Aufgaben:${tasks.isEmpty ? ' -' : '\n   - ${tasks.join('\n   - ')}'}'),
      Text('Notizen ${tp.notes}')
    ]);
  }

  Widget renderActiveTrackPoint(BuildContext context) {
    if (runningTrackPoints.isEmpty) {
      return const Text('...waiting for GPS...');
    } else {
      try {
        Widget textInfo = activeTrackPointInfo(
            status: currentStatus,
            timeStart: runningTrackPoints.last.time,
            timeEnd: runningTrackPoints.first.time,
            alias: ModelAlias.nextAlias(currentStatus == TrackingStatus.moving
                    ? runningTrackPoints.first
                    : runningTrackPoints.last)
                .map((e) {
              return '- ${e.alias}';
            }).toList(),
            task: ModelTrackPoint.pendingTrackPoint.idTask
                .map((e) => '- ${ModelTask.getTask(e).task}')
                .toList(),
            duration: util.duration(
                runningTrackPoints.last.time, runningTrackPoints.first.time),
            notes: ModelTrackPoint.pendingTrackPoint.notes);

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
                  Navigator.pushNamed(
                      context, AppRoutes.editTrackingTasks.route);
                }),
            title: textInfo);
      } catch (e, stk) {
        logger.warn(e.toString());
        return Text('$e');
      }
    }
  }

  ///
  ///
  ///
  List<Widget> renderTrackPointList(
      BuildContext context, List<ModelTrackPoint> tpList) {
    List<Widget> listItems = [];
    try {
      for (var tp in tpList) {
        if (tp.status == TrackingStatus.standing) {
          listItems.add(ListTile(
            title: recentTrackPointInfo(tp),
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
            CheckboxModel(
                idReference: task.id,
                referenceList: referenceList,
                title: task.task,
                subtitle: task.notes));
      }).toList()
    ];
    return list;
  }

  Widget editTasks(BuildContext context, CheckboxModel model) {
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
