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

class _TrackPointListView extends State<TrackPointListView> {
  static final List<TrackingStatusChangedEvent> _trackPointsStatusChanged = [];
  static final List<Widget> listView = [];
  static StreamSubscription? _trackingStatusListener;
  static StreamSubscription? _trackPointListener;

  _TrackPointListView() {
    _trackingStatusListener ??= trackingStatusEvents
        .on<TrackingStatusChangedEvent>()
        .listen(onTrackingStatusChanged);
    _trackPointListener ??=
        trackPointEvent.on<TrackPointEvent>().listen(onTrackPoint);
  }

  // add a new Trackpoint list item
  // and prune list to max of 100
  void onTrackingStatusChanged(TrackingStatusChangedEvent event) {
    _trackPointsStatusChanged.add(event);
    listView.add(renderTrackPoint(event.trackPoints, event.status));
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
    listView[listView.length - 1] = renderTrackPoint(
        event.trackPoints, _trackPointsStatusChanged.last.status);
    setState(() {});
  }

  // render a listView item
  Table renderTrackPoint(List<TrackPoint> trackPoints, TrackingStatus status) {
    TrackPoint trackPoint = trackPoints.last;
    double dist;
    if (status == TrackingStatus.start) {
      // calc distance over all trackpoints as waypoints
      dist = TrackPoint.movedDistance(
                  trackPoints.getRange(0, trackPoints.length - 2).toList())
              .round() /
          1000;
    } else {
      // calc distance from stooped point to recent point as straight line
      dist = TrackPoint.movedDistance(<TrackPoint>[
            _trackPointsStatusChanged.last.trackPoints.last,
            trackPoints.elementAt(trackPoints.length - 2)
          ]).round() /
          1000;
    }

    TableCell row1 = TableCell(
        child: Center(
            child: Text(
                'Status: ${status == TrackingStatus.start ? 'Fahren (${dist}km)' : 'Halt (${dist}km)'}')));

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
    return table;
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> items = [...listView.reversed.toList()];
    return ListView(children: items);
  }
}
