// ignore_for_file: prefer_final_fields, prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:flutter/material.dart';
//
import 'package:chaostours/logger.dart';
import 'package:chaostours/event_manager.dart';
import 'package:chaostours/trackpoint.dart';
import 'package:chaostours/util.dart' as util;
import 'package:chaostours/enum.dart';
import 'package:chaostours/shared/shared.dart';
import 'package:chaostours/model/model_alias.dart';
import 'package:chaostours/model/model_task.dart';
import 'package:chaostours/model/model_trackpoint.dart';
//
import 'package:chaostours/page/widget_add_tasks_page.dart';
import 'package:chaostours/widget/widget_drawer.dart';
import 'package:chaostours/widget/widgets.dart';
import 'package:chaostours/widget/widget_bottom_navbar.dart';
import 'package:chaostours/address.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/shared/shared_data.dart';
import 'package:chaostours/screen.dart';

class WidgetTrackingPage extends StatefulWidget {
  const WidgetTrackingPage({super.key});

  @override
  State<WidgetTrackingPage> createState() => _WidgetTrackingPage();
}

class _WidgetTrackingPage extends State<WidgetTrackingPage> {
  static Logger logger = Logger.logger<WidgetTrackingPage>();

  ///
  /// active trackpoint data
  static TrackingStatus lastStatus = TrackingStatus.none;
  static TrackingStatus currentStatus = TrackingStatus.none;

  Widget activeTrackPointRendered = Text('...waiting for GPS...');
  List<Widget> recentTrackPointsRendered = [];

  /// recent or saved trackponts
  static List<GPS> runningTrackPoints = [];

  _WidgetTrackingPage() {
    EventManager.listen<EventOnAppTick>(onTick);
    EventManager.listen<EventOnAddressLookup>(onAddressLookup);
  }

  @override
  void dispose() {
    EventManager.remove<EventOnAppTick>(onTick);
    EventManager.remove<EventOnAddressLookup>(onAddressLookup);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Widgets.appBar(),
      drawer: const WidgetDrawer(),
      body: ListView(children: [
        activeTrackPointRendered,
        Divider(thickness: 2, indent: 10, endIndent: 10, color: Colors.black),
        ...recentTrackPointsRendered
      ]),
      bottomNavigationBar: const WidgetBottomNavBar(),
    );
  }

  Future<void> onAddressLookup(EventOnAddressLookup event) async {
    ModelTrackPoint.pendingAddressLookup =
        (await ModelTrackPoint.pendingTrackPoint?.address.lookupAddress())
                ?.asString ??
            '';
  }

  Future<void> onTick(EventOnAppTick tick) async {
    Shared shared = Shared(SharedKeys.trackPointUp);
    List<String> sharedList = await shared.loadList() ?? [];
    if (sharedList.isNotEmpty) {
      try {
        /// get status
        TrackingStatus status = TrackingStatus.values.byName(sharedList[0]);
        if (sharedList.length > 1) {
          sharedList.removeAt(0);
          try {
            runningTrackPoints.clear();
            for (var row in sharedList) {
              runningTrackPoints.add(GPS.toSharedObject(row));
            }

            /// update pendingTrackPoint
            if (ModelTrackPoint.pendingTrackPoint == null) {
              /// initial appStart
              ModelTrackPoint.pendingTrackPoint = createTrackPoint(status);
            } else {
              /// update
              ModelTrackPoint.pendingTrackPoint!
                ..address = Address(runningTrackPoints.first)
                ..trackPoints = runningTrackPoints
                ..timeEnd = runningTrackPoints.first.time
                ..idAlias = ModelAlias.nextAlias(runningTrackPoints.first)
                    .map((e) => e.id)
                    .toList()
                ..idTask = ModelTrackPoint.pendingTasks
                ..notes = ModelTrackPoint.pendingNotes;
            }

            /// write to share user data to background thread
            await Shared(SharedKeys.trackPointDown).saveString(
                ModelTrackPoint.pendingTrackPoint!.toSharedString());

            /// status has changed
            if (status != lastStatus && lastStatus != TrackingStatus.none) {
              currentStatus = status;
              await statusChanged();
            }
          } catch (e, stk) {
            logger.error(e.toString(), stk);
          }
        }
      } catch (e, stk) {
        logger.error(e.toString(), stk);
      }
    }
    activeTrackPointRendered = await renderActiveTrackPoint();
    recentTrackPointsRendered = renderRecentTrackPoints();

    setState(() {});
  }

  ModelTrackPoint createTrackPoint(TrackingStatus status) {
    GPS gps = runningTrackPoints.first;
    ModelTrackPoint tp = ModelTrackPoint(
        address: Address(gps),
        gps: gps,
        trackPoints: runningTrackPoints,
        idAlias: ModelAlias.nextAlias(gps).map((e) => e.id).toList(),
        timeStart: gps.time);
    tp.status = status;
    tp.timeEnd = runningTrackPoints.last.time;
    tp.idTask = ModelTrackPoint.pendingTasks;
    tp.notes = ModelTrackPoint.pendingNotes;
    return tp;
  }

  Future<void> statusChanged() async {
    logger.important(
        'TrackingStatus changed from ${lastStatus.name} to ${currentStatus.name}');
    if (lastStatus == TrackingStatus.standing) {
      logger.important('insert new TrackPoint');
      ModelTrackPoint tp =
          ModelTrackPoint.pendingTrackPoint ?? createTrackPoint(lastStatus);
      try {
        await tp.address.lookupAddress();
      } catch (e, stk) {
        logger.error('lookup address on status changed: ${e.toString()}', stk);
      }

      //await ModelTrackPoint.insert(tp);
      lastStatus = currentStatus;
    }
  }

  Widget trackPointInfo(
      {required TrackingStatus status,
      required DateTime timeStart,
      required DateTime timeEnd,
      required Duration duration,
      required Address address,
      required List<String> alias,
      required List<String> task,
      required String notes}) {
    return ListBody(
      children: [
        Center(
            heightFactor: 2,
            child: Text(status.name,
                style: TextStyle(letterSpacing: 2, fontSize: 20))),
        Center(
            heightFactor: 1,
            child: Text(
                'von ${util.formatDate(timeStart)} '
                '\nbis ${util.formatDate(timeEnd)} \n'
                '(${util.timeElapsed(timeStart, timeEnd, false)})',
                softWrap: true)),
        Text('OSM: "${ModelTrackPoint.pendingAddressLookup}"', softWrap: true),
        Text('Alias: ${alias.join('\n       ')}', softWrap: true),
        Divider(
            thickness: 1, indent: 10, endIndent: 10, color: Colors.blueGrey),
        Text('Aufgaben: ${task.join('\n      ')}', softWrap: true),
        Divider(
            thickness: 1, indent: 10, endIndent: 10, color: Colors.blueGrey),
        Text('Notizen: $notes')
      ],
    );
  }

  Future<Widget> renderActiveTrackPoint() async {
    Screen screen = Screen(context);
    if (ModelTrackPoint.pendingTrackPoint == null) {
      return const Text('...waiting for GPS...');
    } else {
      try {
        GPS gps = runningTrackPoints.first;
        List<GPS> rtp = runningTrackPoints;
        DateTime timeStart = rtp.last.time;
        DateTime timeEnd = rtp.first.time;
        String readableDuration = util.timeElapsed(timeEnd, timeStart, false);
        String status =
            lastStatus == TrackingStatus.moving ? 'Fahren' : 'Halten';

        /// address
        String address = 'not implemented';

        /// alias
        List<String> alias = ModelAlias.nextAlias(rtp.last).map((e) {
          return '- ${e.alias}';
        }).toList();

        /// pending tasks
        List<String> task = ModelTrackPoint.pendingTasks
            .map((e) => '- ${ModelTask.getTask(e).task}')
            .toList();

        /// pending trackpoint notes
        String notes = ModelTrackPoint.pendingNotes;

        Widget textInfo = trackPointInfo(
            status: currentStatus,
            address: ModelTrackPoint.pendingTrackPoint!.address,
            timeStart: timeStart,
            timeEnd: timeEnd,
            alias: alias,
            task: task,
            duration: util.duration(timeStart, timeEnd),
            notes: notes);

        ///
        /// create widget
        ///
        return Table(defaultColumnWidth: IntrinsicColumnWidth(), columnWidths: {
          0: FixedColumnWidth(screen.percentWidth(10)),
          1: FixedColumnWidth(screen.percentWidth(90)),
        }, children: [
          /// Row 1
          TableRow(children: [
            /// Row 1, col 1 (icon button)
            TableCell(
                verticalAlignment: TableCellVerticalAlignment.middle,
                child: IconButton(
                    icon: Icon(size: 50, Icons.edit_location),
                    onPressed: () {})),

            /// Row 1, col 2 (trackpoint information in some rows)
            TableCell(child: textInfo)
          ])
        ]);
      } catch (e, stk) {
        logger.error(e.toString(), stk);
        return Text('$e');
      }
    }
  }

  ///
  ///
  ///
  List<Widget> renderRecentTrackPoints() {
    List<Widget> listItems = [];
    try {
      List<ModelTrackPoint> tpList = ModelTrackPoint.recentTrackPoints();
      for (var tp in tpList) {
        DateTime timeStart = tp.timeStart;
        DateTime timeEnd = tp.timeEnd;
        String readableDuration = util.timeElapsed(timeEnd, timeStart, false);
        String status = tp.status == TrackingStatus.moving ? 'Fahren' : 'Halt';
        String address = tp.address.asString;
        String alias = tp.idAlias
            .map((e) {
              return '- ${ModelAlias.getAlias(e).alias}';
            })
            .toList()
            .join('\n');
        String task = tp.idTask
            .map((e) {
              return '- ${ModelTask.getTask(e).task}';
            })
            .toList()
            .join('\n');
        List<String> taskNotes = tp.idTask.map((e) {
          return ModelTask.getTask(e).notes;
        }).toList();
        String notes = tp.notes;
        if (tp.status == TrackingStatus.standing) {
          listItems.add(
            Table(columnWidths: {
              0: FixedColumnWidth(50),
              1: FractionColumnWidth(.8),
            }, children: [
              /// Row 1
              TableRow(children: [
                /// Row 1, col 1 (icon button)
                TableCell(
                    child: IconButton(
                        icon: Icon(Icons.edit_location_outlined),
                        onPressed: () {})),

                /// Row 1, col 2 (trackpoint information in some rows)
                TableCell(
                    child: ListBody(
                  children: [
                    Center(
                        heightFactor: 1.5,
                        child: Text('von ${util.formatDate(timeStart)} '
                            '\nbis ${util.formatDate(timeEnd)} \n'
                            '($readableDuration)')),
                    Text('OSM: "$address"'),
                    Text('Alias: $alias'),
                    Text('Aufgaben: $task')
                  ],
                ))
              ])
            ]),
          );
          listItems.add(Divider(
              thickness: 2, indent: 10, endIndent: 10, color: Colors.black));
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
}
