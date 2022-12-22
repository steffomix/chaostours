import 'dart:async';
import 'package:flutter/material.dart';
import 'package:chaostours/events.dart';
import 'package:chaostours/track_point.dart';
import 'package:chaostours/log.dart';

class TrackPointListView extends StatefulWidget {
  const TrackPointListView({super.key});

  @override
  State<TrackPointListView> createState() => _TrackPointListView();
}

class _TrackPointListItem {
  final TrackPointEvent event;

  _TrackPointListItem(this.event);

  Widget get asTable {
    TrackPoint trackPoint = event.caused;
    double dist = event.status == TrackingStatus.moving
        ? event.distancePath
        : event.distanceStraight;

    TableCell row1 = TableCell(
        child: Center(
            child: Text(
                'Status: ${event.status == TrackingStatus.moving ? 'Fahren (${dist}km)' : 'Halt (${dist}km)'}')));

    TableCell row2 =
        TableCell(child: Center(child: Text(trackPoint.address.asString)));

    TableCell row3 = TableCell(
        child: Center(
            child: Text(trackPoint.alias.isNotEmpty
                ? 'Alias ${trackPoint.alias[0].alias}'
                : ' - ')));

    Table table = Table(
        border: const TableBorder(top: BorderSide(style: BorderStyle.solid)),
        children: <TableRow>[
          TableRow(children: <Widget>[row1]),
          TableRow(children: <Widget>[row2]),
          TableRow(children: <Widget>[row3])
        ]);

    Listener listener = Listener(
      child: table,
      onPointerDown: (PointerDownEvent e) {
        onTapEvent.fire(event);
      },
    );
    return listener;
  }
}

class _TrackPointListView extends State<TrackPointListView> {
  static final List<TrackPointEvent> _trackPointsStatusChanged = [];
  static final List<Widget> listView = [];
  static StreamSubscription? _trackingStatusListener;
  static StreamSubscription? _trackPointListener;

  _TrackPointListView() {
    _trackingStatusListener ??= trackingStatusChangedEvents
        .on<TrackPointEvent>()
        .listen(onTrackingStatusChanged);
    _trackPointListener ??=
        trackPointCreatedEvents.on<TrackPointEvent>().listen(onTrackPoint);
  }

  // add a new Trackpoint list item
  // and prune list to max of 100
  void onTrackingStatusChanged(TrackPointEvent event) {
    _trackPointsStatusChanged.add(event);
    listView.add(_TrackPointListItem(event).asTable);
    while (listView.length > 100) {
      listView.removeLast();
    }
    setState(() {});
  }

  void onTapItem(TrackPoint trackPoint, TrackingStatus status) {
    logInfo('OnTapItem');
  }

  // update last trackpoint list item
  void onTrackPoint(TrackPointEvent event) {
    if (_trackPointsStatusChanged.isEmpty) return;
    listView[listView.length - 1] = _TrackPointListItem(event).asTable;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> items = [...listView.reversed.toList()];
    return ListView(children: items);
  }
}
