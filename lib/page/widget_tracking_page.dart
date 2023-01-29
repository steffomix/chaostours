// ignore_for_file: prefer_final_fields

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
    var d = data;

    setState(() {});
  }

  Widget renderActiveTrackpoint(BuildContext context) {
    try {
      String status =
          data.status == TrackingStatus.standing ? 'Halt' : 'Fahren';
      Duration dur = data.runningTrackPoints.last.time
          .difference(data.runningTrackPoints.first.time);

      return ListView(children: [
        Center(
            heightFactor: 1.5,
            child: Text(
              '$status für ${dur.toString()}',
              textScaleFactor: 2,
            )),
        Text(data.runningTrackPoints.map((e) => e.toString()).join('\n'))
      ]);
    } catch (e) {
      return SizedBox(
          height: 100, child: Text('...waiting for trackpoints\n $e'));
    }
/*
    /// try to get an alias from running trackpoints
    String alias = '- no alias found -';
    String address = '- no address found yet -';
    if (activeRunningTrackpoints.isNotEmpty) {
      List<ModelAlias> aliasList =
          ModelAlias.nextAlias(activeRunningTrackpoints.last.gps);
      if (aliasList.isNotEmpty) {
        alias = aliasList.first.alias;
      }
    }

    return Container();
    */
  }

  Widget renderRecentTrackPoint(int id) {
    return Container();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Widgets.appBar(),
      drawer: const WidgetDrawer(),
      body: renderActiveTrackpoint(context),
      bottomNavigationBar: const WidgetBottomNavBar(),
    );
  }
}
