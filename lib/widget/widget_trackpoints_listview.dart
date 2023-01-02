import 'dart:async';
import 'package:flutter/material.dart';
import 'package:chaostours/events.dart';
import 'package:chaostours/track_point.dart';
import 'package:chaostours/log.dart';
import 'package:chaostours/util.dart' as util;
import 'package:chaostours/enum.dart';
import 'widget_add_tasks.dart';
import 'package:chaostours/globals.dart';
import 'package:chaostours/model_alias.dart';
import 'package:chaostours/model_task.dart';
import 'package:chaostours/model_trackpoint.dart';

class WidgetModelTrackPointList extends StatefulWidget {
  const WidgetModelTrackPointList({super.key});

  @override
  State<WidgetModelTrackPointList> createState() => _TrackPointListView();
}

class _TrackPointListView extends State<WidgetModelTrackPointList> {
  static ModelTrackPoint? lastEvent;
  static bool init = false;
  static final List<Widget> listView = [];
  StreamSubscription? _trackingStatusListener;
  StreamSubscription? _trackPointListener;

  _TrackPointListView() {
    _trackingStatusListener ??= eventBusTrackingStatusChanged
        .on<ModelTrackPoint>()
        .listen(onTrackingStatusChanged);
    _trackPointListener ??=
        eventBusTrackPointCreated.on<ModelTrackPoint>().listen(onTrackPoint);
    listView.clear();
    int count = 30;
    for (var e in ModelTrackPoint.recentTrackPoints(max: count)) {
      e.status = TrackingStatus.standing;
      listView.add(createListItem(e));
    }
    listView.add(const Divider(color: Colors.black));
    listView.add(const Divider(color: Colors.black));
    listView.add(const Center(child: Text('Gespeicherte Einträge')));
    listView.add(const Divider(color: Colors.black));
    listView.add(const Divider(color: Colors.black));
    if (lastEvent != null && init) listView.add(createListItem(lastEvent!));
    init = true;
  }

  @override
  void dispose() {
    _trackingStatusListener?.cancel();
    _trackPointListener?.cancel();
    super.dispose();
  }

  // add a new Trackpoint list item
  // and prune list to max of 100
  void onTrackingStatusChanged(ModelTrackPoint event) {
    listView.add(createListItem(event, false));
    while (listView.length > 100) {
      listView.removeLast();
    }
    //setState(() {});
  }

  void onTapItem(TrackPoint trackPoint, TrackingStatus status) {
    logInfo('OnTapItem');
  }

  // update last trackpoint list item
  void onTrackPoint(ModelTrackPoint event) {
    lastEvent = event;
    listView[listView.length - 1] = createListItem(event, true);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> items = [...listView.reversed.toList()];
    return ListView(children: items);
  }

  ///
  /// creates a list item from TrackPoint
  ///
  String ev = '';
  String up = '';
  Widget createListItem(ModelTrackPoint event, [bool update = true]) {
    ev += event.status.index.toString();
    up += (update == true ? 1 : 0).toString();
    lastEvent = event;
    // calculate duration and distance
    String duration = TrackPoint.timeElapsed();

    double distance = TrackPoint.distance();

    // left section (icon)
    var icon = event.status == TrackingStatus.standing
        ? Icons.edit
        : Icons.info_outline;

    Widget left = IconButton(
      icon: Icon(icon),
      onPressed: () {
        Globals.mainPane = WidgetAddTasks(trackPoint: event);
      },
    );

    // prepare rows for right section (info)
    List<TableRow> rows = [];
    String text;

    ///
    /// first line (status, time, duration and distance)
    ///
    text = event.status == TrackingStatus.moving
        ? 'Fahren: ${distance}km in $duration'
        : 'Halt am ${util.formatDate(event.timeStart)}\nfür $duration';
    rows.add(TableRow(children: <Widget>[
      TableCell(
          child: Center(
              child: Text(text,
                  style: const TextStyle(fontWeight: FontWeight.bold))))
    ]));

    ///
    /// second row (address)
    ///
    if (event.address.loaded) {
      text = 'OSM: ${event.address.asString}';
      rows.add(TableRow(
          children: <Widget>[TableCell(child: Center(child: Text(text)))]));
    }
    if (event.idAlias.isNotEmpty) {
      text = 'Alias: ${ModelAlias.getAlias(event.idAlias.first).alias}';
      rows.add(TableRow(
          children: <Widget>[TableCell(child: Center(child: Text(text)))]));
    }
    if (!event.address.loaded && event.idAlias.isEmpty) {
      //https://maps.google.com&q=lat,lon&center=lat,lon
      text =
          'GPS: ${(event.gps.lat * 10000).round() / 10000},${(event.gps.lon * 10000).round() / 10000}';
      rows.add(TableRow(children: <Widget>[Center(child: Text(text))]));
      //'&center=${event.lat},${event.lon}';

      // rows.add(TableRow(children: <Widget>[
      //   TableCell(
      //       child: Center(
      //           child: InkWell(
      //     child: Text(text),
      //     onTap: () {
      //       launchUrl(
      //           Uri(scheme: 'https', host: 'maps.google.com', queryParameters: {
      //         'q': '${event.lat},${event.lon}',
      //         //'center': '${event.lat},${event.lon}'
      //       }));
      //     },
      //   )))
      // ]));

    }

    ///
    /// third row (tasks)
    ///
    List<TableRow> tasks = [];
    ModelTrackPoint model = event;
    for (var task in model.idTask) {
      ModelTask.getTask(task);
      tasks.add(TableRow(children: [
        const TableCell(child: Text('')),
        TableCell(
            child: Center(child: Text('- ${ModelTask.getTask(task).task}')))
      ]));
    }

    // combine right rows to a table
    Widget right = Table(
        border: const TableBorder(top: BorderSide(style: BorderStyle.solid)),
        children: rows);

    // put left section (table with one row) and right section (table with flexible rows) in another table
    // to simulate html rowspan
    return Table(
      columnWidths: const {0: FlexColumnWidth(1), 1: FlexColumnWidth(8)},
      children: [
        TableRow(children: [TableCell(child: left), TableCell(child: right)]),
        const TableRow(
            children: [TableCell(child: Text('')), TableCell(child: Text(''))]),
        ...tasks
      ],
    );
  }
}
