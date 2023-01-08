import 'dart:async';
//
import 'package:flutter/material.dart';
import 'package:chaostours/events.dart';
import 'package:chaostours/trackpoint.dart';
import 'package:chaostours/log.dart';
import 'package:chaostours/util.dart' as util;
import 'package:chaostours/enum.dart';
import 'package:chaostours/widget/widget_add_tasks.dart';
import 'package:chaostours/model_alias.dart';
import 'package:chaostours/model_task.dart';
import 'package:chaostours/model_trackpoint.dart';
import 'package:chaostours/tracking.dart';

class WidgetTrackPointList extends StatefulWidget {
  const WidgetTrackPointList({super.key});

  @override
  State<WidgetTrackPointList> createState() => _TrackPointListView();
}

class _TrackPointListView extends State<WidgetTrackPointList> {
  static _ActiveListItem? activeItem;
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
      //e.status = TrackingStatus.standing;
      listView.add(_ActiveListItem(e).widget);
    }
    listView
        .add(const Divider(color: Colors.black, thickness: 3.0, height: 5.0));
    listView.add(const Center(child: Text('Gespeicherte Einträge')));
    listView
        .add(const Divider(color: Colors.black, thickness: 3.0, height: 5.0));
    listView.add(const Text(''));
    listView.add(const Text('')); // to be replaced with active item
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
    if (activeItem == null) {
      return onTrackPoint(event);
    } else {
      listView.add(activeItem!.widget);
      activeItem = _ActiveListItem(event);
    }

    while (listView.length > 100) {
      listView.removeLast();
    }
    setState(() {});
  }

  void onTapItem(TrackPoint trackPoint, TrackingStatus status) {
    logInfo('OnTapItem');
  }

  // update last trackpoint list item
  void onTrackPoint(ModelTrackPoint event) {
    activeItem ??= _ActiveListItem(event);
    activeItem?.update(event);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> items = [
      activeItem?.widget ?? const Text('...waiting for Trackpoint.')
    ];
    items.addAll(listView.reversed.toList());
    String db = '';

    items.add(TextField(
      keyboardType: TextInputType.multiline,
      maxLines: null,
      controller: TextEditingController(text: ModelTrackPoint.dumpTable()),
    ));
    return ListView(children: items);
  }
}

///
///
///
///

class _ActiveListItem {
  final ModelTrackPoint event;
  Widget? _widget;
  _ActiveListItem(this.event);

  Widget get widget {
    Widget w = _widget ??= _createWidget();
    return w;
  }

  Widget update(ModelTrackPoint tp) {
    event.deleted = tp.deleted;
    event.gps = tp.gps;
    event.address = tp.address;
    event.idAlias = tp.idAlias;
    event.timeEnd = DateTime.now();
    return (_widget = _createWidget());
  }

  ///
  /// creates a list item from TrackPoint
  ///
  Widget _createWidget() {
    // calculate duration and distance
    String duration = event.timeElapsed();

    double distance = event.distance();

    TextStyle fatStyle = const TextStyle(fontWeight: FontWeight.bold);

    // left section (icon)
    var icon = event.status == TrackingStatus.standing
        ? Icons.edit
        : Icons.info_outline;

    Widget left = IconButton(
      icon: Icon(icon),
      onPressed: () {
        eventBusMainPaneChanged.fire(WidgetAddTasks(trackPoint: event));
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
      TableCell(child: Center(child: Text(text, style: fatStyle)))
    ]));

    ///// Alias
    if (event.idAlias.isNotEmpty && event.status == TrackingStatus.standing) {
      text = ModelAlias.getAlias(event.idAlias.first).alias;
      rows.add(TableRow(children: <Widget>[
        TableCell(child: Center(child: Text(text, style: fatStyle)))
      ]));
    }

    ///
    /// second row (address)
    ///
    ///// OSM
    if (event.address.loaded && event.status == TrackingStatus.standing) {
      text = '(OSM: ${event.address.asString})';
      rows.add(TableRow(
          children: <Widget>[TableCell(child: Center(child: Text(text)))]));
    }
    ///// Link
    if (!event.address.loaded &&
        event.idAlias.isEmpty &&
        event.status == TrackingStatus.standing) {
      //https://maps.google.com&q=lat,lon&center=lat,lon
      text =
          'GPS: ${(event.gps.lat * 10000).round() / 10000},${(event.gps.lon * 10000).round() / 10000}';
      rows.add(TableRow(children: <Widget>[Center(child: Text(text))]));
      //'&center=${event.lat},${event.lon}';

      // rows.add(TableRow(children: <Widget>[
      //   TableCell(
      //       child: Center(
      //           child: InkWell(
      //     child: Text(gpsText),
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

    String gpsText =
        'Trackpoints: ${TrackPoint.length}, Trackings: ${Tracking.counter}';
    TableRow gpsInfo = TableRow(children: [
      const TableCell(child: Text('')),
      TableCell(child: Text(gpsText))
    ]);

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
        ...tasks,
        gpsInfo
      ],
    );
  }
}
