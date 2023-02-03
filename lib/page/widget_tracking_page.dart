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

  /// recent or saved trackponts
  static List<ModelTrackPoint> recentTrackpoints = [];
  static List<GPS> runningTrackPoints = [];

  _WidgetTrackingPage() {
    updateActiveTrackpoint();
    EventManager.listen<EventOnTick>(onTick);
  }

  Future<void> updateActiveTrackpoint() async {
    recentTrackpoints = ModelTrackPoint.recentTrackPoints();
  }

  @override
  void dispose() {
    EventManager.remove<EventOnTick>(onTick);
    super.dispose();
  }

  void onTick(EventOnTick tick) async {
    Shared shared = Shared(SharedKeys.trackPointUp);
    List<String> sharedList = await shared.loadList() ?? [];
    if (sharedList.isNotEmpty) {
      try {
        /// get status
        TrackingStatus status = TrackingStatus.values.byName(sharedList[0]);
        if (sharedList.length > 1) {
          sharedList.removeAt(0);

          /// get trackpoints
          List<GPS> trackPoints = [];
          try {
            for (var row in sharedList) {
              trackPoints.add(GPS.toSharedObject(row));
            }
            if (status != lastStatus && lastStatus != TrackingStatus.none) {
              await statusChanged(status, trackPoints);
            }
          } catch (e, stk) {
            logger.error(e.toString(), stk);
          }
          runningTrackPoints = trackPoints;
        }
      } catch (e, stk) {
        logger.error(e.toString(), stk);
      }
    }

    setState(() {});
  }

  Future<void> statusChanged(
      TrackingStatus status, List<GPS> trackPoints) async {
    logger.important(
        'TrackingStatus changed from ${lastStatus.name} to ${status.name}');
    if (lastStatus == TrackingStatus.standing) {
      logger.important('insert new TrackPoint');
      GPS gps = trackPoints.last;
      ModelTrackPoint tp = ModelTrackPoint(
          address: Address(gps),
          gps: gps,
          trackPoints: trackPoints,
          idAlias: ModelAlias.nextAlias(gps).map((e) => e.id).toList(),
          timeStart: gps.time);
      tp.status = lastStatus;
      tp.timeEnd = trackPoints.last.time;
      tp.idTask = ModelTask.pendingTasks;
      tp.notes = ModelTrackPoint.pendingNotes;
      await ModelTrackPoint.insert(tp);
      recentTrackpoints = ModelTrackPoint.recentTrackPoints();
      lastStatus = status;
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget active = renderActiveTrackPoint(context);
    List<Widget> stored = renderStoredTrackPoints(context);
    return Scaffold(
      appBar: Widgets.appBar(),
      drawer: const WidgetDrawer(),
      body: ListView(children: [
        active,
        Divider(thickness: 2, indent: 10, endIndent: 10, color: Colors.black),
        ...stored
      ]),
      bottomNavigationBar: const WidgetBottomNavBar(),
    );
  }

  Widget renderActiveTrackPoint(BuildContext context) {
    if (runningTrackPoints.isEmpty) {
      return const Text('...waiting for GPS...');
    } else {
      try {
        List<GPS> rtp = runningTrackPoints;
        DateTime timeStart = rtp.isEmpty ? DateTime.now() : rtp.first.time;
        DateTime timeEnd = rtp.isEmpty ? DateTime.now() : rtp.last.time;
        Duration dur = timeStart.difference(timeEnd);
        String status =
            lastStatus == TrackingStatus.moving ? 'Fahren' : 'Halten';

        /// address
        String address = 'not implemented';

        /// alias
        String alias = ModelAlias.nextAlias(rtp.last)
            .map((e) {
              return '- ${e.alias}';
            })
            .toList()
            .join('\n');

        /// pending tasks
        String task = ModelTask.pendingTasks
            .map((e) => '- ${ModelTask.getTask(e).task}')
            .toList()
            .join('\n');

        /// notes of pending tasks
        List<String> taskNotes = (ModelTask.pendingTasks).map((e) {
          return ModelTask.getTask(e).notes;
        }).toList();

        /// pending trackpoint notes
        String notes = ModelTrackPoint.pendingNotes;

        ///
        /// create widget
        ///
        return Table(defaultColumnWidth: IntrinsicColumnWidth(), columnWidths: {
          0: FixedColumnWidth(50),
          1: FractionColumnWidth(.8),
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
            TableCell(
                child: ListBody(
              children: [
                Center(
                    heightFactor: 2,
                    child: Text(status,
                        style: TextStyle(letterSpacing: 2, fontSize: 20))),
                Center(
                    heightFactor: 1,
                    child: Text('von ${util.formatDate(timeStart)} '
                        '\nbis ${util.formatDate(timeEnd)} \n'
                        '(${rtp.isEmpty ? '---' : util.timeElapsed(timeStart, timeEnd)})sec.')),
                Text('OSM: "$address"'),
                Text('Alias: $alias'),
                Text('Aufgaben: $task')
              ],
            ))
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
  List<Widget> renderStoredTrackPoints(BuildContext context) {
    List<Widget> listItems = [];
    try {
      List<ModelTrackPoint> tpList = ModelTrackPoint.recentTrackPoints();
      for (var tp in tpList) {
        Duration duration = tp.timeStart.difference(tp.timeEnd);
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
                        child: Text(
                            'Halt: von ${tp.timeStart.toIso8601String()} \nbis ${tp.timeEnd.toIso8601String()}')),
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
