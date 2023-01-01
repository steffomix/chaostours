import 'dart:async';
import 'package:flutter/material.dart';
import 'package:chaostours/events.dart';
import 'package:chaostours/track_point.dart';
import 'package:chaostours/log.dart';
import 'package:chaostours/util.dart' as util;
import 'package:chaostours/enum.dart';
import 'package:chaostours/model_trackpoint.dart';
import 'package:url_launcher/url_launcher.dart';
import 'widget_add_tasks.dart';
import 'package:chaostours/globals.dart';

class WidgetTrackPointEventList extends StatefulWidget {
  const WidgetTrackPointEventList({super.key});

  @override
  State<WidgetTrackPointEventList> createState() => _TrackPointListView();
}

class _TrackPointListView extends State<WidgetTrackPointEventList> {
  static TrackPointEvent? lastEvent;
  static bool init = false;
  static final List<Widget> listView = [];
  StreamSubscription? _trackingStatusListener;
  StreamSubscription? _trackPointListener;

  _TrackPointListView() {
    _trackingStatusListener ??= eventBusTrackingStatusChanged
        .on<TrackPointEvent>()
        .listen(onTrackingStatusChanged);
    _trackPointListener ??=
        eventBusTrackPointCreated.on<TrackPointEvent>().listen(onTrackPoint);
    listView.clear();
    for (var e in TrackPointEvent.recentEvents(max: 30)) {
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
  void onTrackingStatusChanged(TrackPointEvent event) {
    listView.add(createListItem(event));
    while (listView.length > 100) {
      listView.removeLast();
    }
    //setState(() {});
  }

  void onTapItem(TrackPoint trackPoint, TrackingStatus status) {
    logInfo('OnTapItem');
  }

  // update last trackpoint list item
  void onTrackPoint(TrackPointEvent event) {
    lastEvent = event;
    listView[listView.length - 1] = createListItem(event);
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
  Widget createListItem(TrackPointEvent event) {
    lastEvent = event;
    // calculate duration and distance
    String duration = util.timeElapsed(event.timeStart, event.timeEnd);
    num distance = event.status == TrackingStatus.moving
        ? event.distancePath.round() / 1000
        : event.distanceStraight.round();

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

    // first line (status, time, duration and distance)
    text = event.status == TrackingStatus.moving
        ? 'Fahren: ${distance}km in $duration'
        : 'Halt am ${util.formatDate(event.timeStart)}\nfür $duration';
    rows.add(TableRow(children: <Widget>[
      TableCell(
          child: Center(
              child: Text(text,
                  style: const TextStyle(fontWeight: FontWeight.bold))))
    ]));

    /// second row (address)
    if (event.address.loaded) {
      text = 'OSM: ${event.address.asString}';
      rows.add(TableRow(
          children: <Widget>[TableCell(child: Center(child: Text(text)))]));
    }
    if (event.aliasList.isNotEmpty) {
      text = 'Alias: ${event.aliasList.first.alias}';
      rows.add(TableRow(
          children: <Widget>[TableCell(child: Center(child: Text(text)))]));
    }
    if (!event.address.loaded && event.aliasList.isEmpty) {
      //https://maps.google.com&q=lat,lon&center=lat,lon
      text =
          'GPS: ${(event.lat * 10000).round() / 10000},${(event.lon * 10000).round() / 10000}';
      rows.add(TableRow(children: <Widget>[Center(child: Text(text))]));
      //'&center=${event.lat},${event.lon}';
      /*
      rows.add(TableRow(children: <Widget>[
        TableCell(
            child: Center(
                child: InkWell(
          child: Text(text),
          onTap: () {
            launchUrl(
                Uri(scheme: 'https', host: 'maps.google.com', queryParameters: {
              'q': '${event.lat},${event.lon}',
              //'center': '${event.lat},${event.lon}'
            }));
          },
        )))
      ]));
      */
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
            children: [TableCell(child: Text('')), TableCell(child: Text(''))])
      ],
    );
  }
}
