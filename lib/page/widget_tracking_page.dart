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

class WidgetTrackingPage extends StatefulWidget {
  const WidgetTrackingPage({super.key});

  @override
  State<WidgetTrackingPage> createState() => _WidgetTrackingPage();
}

class _WidgetTrackingPage extends State<WidgetTrackingPage> {
  static Logger logger = Logger.logger<WidgetTrackingPage>();

  ///
  /// active trackpoint data
  static TrackingStatus activeStatus = TrackingStatus.none;
  static ModelTrackPoint? activeTrackPoint;
  static List<RunningTrackPoint> activeRunningTrackpoints = [];
  static String activeNotes = '';
  static List<ModelTask> activeTasks = [];
  static List<ModelAlias> activeAlias = [];
  static Address activeAddress = Address(GPS(0, 0));

  /// recent or saved trackponts
  static List<ModelTrackPoint> recentTrackpoints = [];

  _WidgetTrackingPage() {
    updateActiveTrackpoint();
    EventManager.listen<EventOnTick>(onTick);
  }

  Future<void> updateActiveTrackpoint() async {
    recentTrackpoints = ModelTrackPoint.recentTrackPoints();

    /// load status
    activeStatus = TrackingStatus.values.byName(
        (await Shared(SharedKeys.activeTrackPointStatusName).load()) ??
            TrackingStatus.none.name);

    /// load active trackpoint
    String? atp = await Shared(SharedKeys.activeTrackpoint).load();
    if (atp != null) {
      activeTrackPoint = ModelTrackPoint.toSharedModel(atp);

      /// load running trackpoints
      List<String> art =
          (await Shared(SharedKeys.runningTrackpoints).loadList()) ??
              <String>[];
      activeRunningTrackpoints =
          art.map((e) => RunningTrackPoint.toModel(e)).toList();
    }
  }

  @override
  void dispose() {
    EventManager.remove<EventOnTick>(onTick);
    super.dispose();
  }

  void onTick(EventOnTick tick) async {
    String none = TrackingStatus.none.name;
    String status =
        await Shared(SharedKeys.activeTrackPointStatusName).load() ?? none;

    if (status != none) {
      activeStatus = TrackingStatus.values.byName(status);
      await updateActiveTrackpoint();
      await Shared(SharedKeys.activeTrackPointStatusName).save(none);
    }
    setState(() {});
  }

  Widget renderActiveTrackpoint(BuildContext context) {
    if (activeTrackPoint == null) {
      return (const Center(child: Text('Waiting for active Trackpoint...')));
    }

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
  }

  Widget renderRecentTrackPoint(int id) {
    return Container();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Widgets.appBar(),
      drawer: const WidgetDrawer(),
      body: ListView.separated(
        itemCount: recentTrackpoints.length + 1,
        separatorBuilder: (BuildContext context, int index) => const Divider(),
        itemBuilder: (BuildContext context, int index) {
          if (index == 0) {
            return renderActiveTrackpoint(context);
          } else {
            return renderRecentTrackPoint(index - 1);
          }
        },
      ),
      bottomNavigationBar: const WidgetBottomNavBar(),
    );
  }
}
