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
import 'package:xml/xml.dart';

class WidgetTrackingPage extends StatefulWidget {
  const WidgetTrackingPage({super.key});

  @override
  State<WidgetTrackingPage> createState() => _WidgetTrackingPage();
}

class SharedData {
  static const String lineSep = '\n';
  static const String xmlHead = '<?xml version="1.0"?>';

  /// encode, decode
  static String encode(String s) => Uri.encodeFull(s);
  static String decode(String s) => Uri.decodeFull(s);

  String _status = 'none';
  String _trackPoint = '';
  String _runningTrackPoints = '';
  String _notes = '';
  String _tasks = '';
  String _alias = '';
  String _address = '';

  /// xml nodes
  final String nodeStatus = 'status';
  final String nodeTrackPoint = 'trackpoint';
  final String nodeRunningTrackPoints = 'runningtrackpoints';
  final String nodeNotes = 'notes';
  final String nodeTask = 'task';
  final String nodeParentTasks = 'tasks';
  final String nodeAlias = 'alias';
  final String nodeAddress = 'address';
  final String nodeListElement = 'node';

  XmlDocument _xml = XmlDocument.parse('');

  /// get, set status
  TrackingStatus get status {
    return TrackingStatus.values.byName(decode(textNode(nodeStatus)));
  }

  set status(TrackingStatus s) => _status = toNode(nodeStatus, encode(s.name));

  /// get, set trackpoint
  ModelTrackPoint get trackPoint =>
      ModelTrackPoint.toSharedModel(decode(textNode(nodeTrackPoint)));
  //
  set trackPoint(ModelTrackPoint t) =>
      _trackPoint = toNode(nodeTrackPoint, encode(t.toSharedString()));

  /// running status
  List<RunningTrackPoint> get runningTrackPoints {
    List<RunningTrackPoint> list = [];
    var children = node(nodeRunningTrackPoints).children;
    for (var child in children) {
      list.add(RunningTrackPoint.toModel(decode(child.innerText)));
    }
    return list;
  }

  set runningTrackPoints(List<RunningTrackPoint> tpList) {
    List<String> xmlList = [];
    for (var tp in tpList) {
      xmlList.add(toNode(nodeListElement, encode(tp.toSharedString())));
    }
    _runningTrackPoints = toNode(nodeRunningTrackPoints, xmlList.join(lineSep));
  }

  set notes(String n) {
    _notes = toNode(nodeNotes, encode(n));
  }

  String get notes {
    return decode(textNode(nodeNotes));
  }

  /// tasks id list
  set tasks(List<int> t) {
    List<String> taskList = [];
    for (var task in t) {
      taskList.add(toNode(nodeListElement, task.toString()));
    }
    _tasks = toNode(nodeTask, taskList.join(lineSep));
  }

  List<int> get tasks {
    List<int> taskList = [];
    for (var child in node(nodeTask).children) {
      taskList.add(int.parse(child.innerText));
    }
    return taskList;
  }

  /// alias id list
  set alias(List<int> alias) {
    List<String> aliasList = [];
    for (var a in alias) {
      aliasList.add(toNode(nodeAlias, a.toString()));
    }
    _alias = toNode(nodeAlias, aliasList.join(lineSep));
  }

  List<int> get alias {
    List<int> ids = [];
    for (var child in node(nodeAlias).children) {
      ids.add(int.parse(child.innerText));
    }
    return ids;
  }

  set address(String address) {
    _address = toNode(nodeAddress, encode(address));
  }

  String get address {
    return decode(textNode(nodeAddress));
  }

  XmlDocument get xmlDocument {
    String sx = <String>[
      xmlHead,
      _status,
      _trackPoint,
      _runningTrackPoints,
      _notes,
      _tasks,
      _alias,
      _address
    ].join(lineSep);

    return XmlDocument.parse(sx);
  }

  XmlElement node(String name) {
    return _xml.findAllElements(name).first;
  }

  String textNode(String name) {
    return _xml.findAllElements(name).first.innerText;
  }

  String toNode(String node, String value) {
    return '<$node>$value</$node>';
  }
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
