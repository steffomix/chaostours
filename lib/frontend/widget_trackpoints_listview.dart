import 'dart:async';
import 'package:flutter/material.dart';
import 'package:chaostours/events.dart';
import 'package:chaostours/track_point.dart';
import 'package:chaostours/log.dart';
import 'package:chaostours/util.dart' as util;
import 'package:chaostours/enum.dart';
import 'package:googleapis/tagmanager/v1.dart';

class TrackPointListView extends StatefulWidget {
  const TrackPointListView({super.key});

  @override
  State<TrackPointListView> createState() => _TrackPointListView();
}

class _TrackPointListItem {
  final TrackPointEvent event;

  _TrackPointListItem(this.event);

  Widget get asWidget {
    TrackPoint trackPoint = event.caused;
    String duration =
        util.timeElapsed(event.trackList.last.time, event.trackList.first.time);
    num distance = event.status == TrackingStatus.moving
        ? event.distancePath.round() / 1000
        : event.distanceStraight.round();

    String t1 = event.status == TrackingStatus.moving
        ? 'Fahren: ${distance}km in $duration'
        : 'Halt $duration';

    String t2 = trackPoint.address.asString;

    String t3 = trackPoint.alias.isNotEmpty
        ? 'Alias ${trackPoint.alias[0].alias}'
        : ' - ';

    var icon = event.status == TrackingStatus.standing
        ? Icons.edit
        : Icons.info_outline;
    Widget left = IconButton(
      icon: Icon(icon),
      onPressed: () {
        eventBusTapTrackPointListItem.fire(event);
        eventBusAppBodyScreenChanged.fire(AppBodyScreens.trackPointEditView);
      },
    );

    Widget right = Table(
        border: const TableBorder(top: BorderSide(style: BorderStyle.solid)),
        children: <TableRow>[
          TableRow(children: <Widget>[
            TableCell(
                child: Center(
                    child: Text(t1,
                        style: const TextStyle(fontWeight: FontWeight.bold))))
          ]),
          TableRow(
              children: <Widget>[TableCell(child: Center(child: Text(t2)))]),
          TableRow(
              children: <Widget>[TableCell(child: Center(child: Text(t3)))])
        ]);

    return Table(
      columnWidths: const {0: FlexColumnWidth(1), 1: FlexColumnWidth(5)},
      children: [
        TableRow(children: [TableCell(child: left), TableCell(child: right)]),
        const TableRow(
            children: [TableCell(child: Text('')), TableCell(child: Text(''))])
      ],
    );
  }
}

class _TrackPointListView extends State<TrackPointListView> {
  static final List<Widget> listView = [];
  static final List<TrackPointEvent> _trackPointsStatusChanged = [];
  StreamSubscription? _trackingStatusListener;
  StreamSubscription? _trackPointListener;

  _TrackPointListView() {
    _trackingStatusListener ??= eventBusTrackingStatusChanged
        .on<TrackPointEvent>()
        .listen(onTrackingStatusChanged);
    _trackPointListener ??=
        eventBusTrackPointCreated.on<TrackPointEvent>().listen(onTrackPoint);
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
    _trackPointsStatusChanged.add(event);
    listView.add(_TrackPointListItem(event).asWidget);
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
    int last = _trackPointsStatusChanged.length - 1;
    _trackPointsStatusChanged[last] = event;
    listView[listView.length - 1] = _TrackPointListItem(event).asWidget;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> items = [...listView.reversed.toList()];
    return ListView(children: items);
  }
}
