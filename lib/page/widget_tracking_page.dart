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
  static SharedData data = SharedData();
  static TrackingStatus lastStatus = TrackingStatus.none;

  /// recent or saved trackponts
  static List<ModelTrackPoint> recentTrackpoints = [];

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
    data = SharedData();

    await data.read();

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    Widget active = renderActiveTrackPoint(context);
    List<Widget> stored = renderStoredTrackPoints(context);
    return Scaffold(
      appBar: Widgets.appBar(),
      drawer: const WidgetDrawer(),
      body: ListView(children: [active, ...stored]),
      bottomNavigationBar: const WidgetBottomNavBar(),
    );
  }

  Widget renderActiveTrackPoint(BuildContext context) {
    try {
      ModelTrackPoint tp = data.trackPoint;
      List<RunningTrackPoint> runningTp = data.runningTrackPoints;
      DateTime timeStart = runningTp.first.time;
      DateTime timeEnd = runningTp.last.time;
      Duration dur = timeStart.difference(timeEnd);
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
      return Table(columnWidths: {
        1: FixedColumnWidth(10),
        2: FixedColumnWidth(90)
      }, children: [
        /// Row 1
        TableRow(children: [
          /// Row 1, col 1 (icon button)
          TableCell(
              child: IconButton(
                  icon: Icon(Icons.edit_attributes), onPressed: () {})),

          /// Row 1, col 2 (trackpoint information in some rows)
          TableCell(
              child: Row(
            children: [
              Center(
                  heightFactor: 1.5,
                  child: Text(
                      'Halt: von ${tp.timeStart.toIso8601String()} bis ${tp.timeEnd.toIso8601String()}')),
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

  List<Widget> renderStoredTrackPoints(BuildContext context) {
    try{
    List<ModelTrackPoint> tpList = ModelTrackPoint.recentTrackPoints();
    List<Widget> listItems = [];
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
        listItems.add(Table(columnWidths: {
          1: FixedColumnWidth(10),
          2: FixedColumnWidth(90)
        }, children: [
          /// Row 1
          TableRow(children: [
            /// Row 1, col 1 (icon button)
            TableCell(
                child: IconButton(
                    icon: Icon(Icons.edit_attributes), onPressed: () {})),

            /// Row 1, col 2 (trackpoint information in some rows)
            TableCell(
                child: Row(
              children: [
                Center(
                    heightFactor: 1.5,
                    child: Text(
                        'Halt: von ${tp.timeStart.toIso8601String()} bis ${tp.timeEnd.toIso8601String()}')),
                Text('OSM: "$address"'),
                Text('Alias: $alias'),
                Text('Aufgaben: $task')
              ],
            ))
          ])
        ]));
      } else {
        return ListView(Text('wrong status');
      }
    }

    return listItems.reversed.toList();
  }
}
