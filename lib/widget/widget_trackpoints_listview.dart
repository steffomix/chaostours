import 'dart:async';
import 'package:flutter/material.dart';
import 'package:chaostours/events.dart';
import 'package:chaostours/track_point.dart';
import 'package:chaostours/log.dart';
import 'package:chaostours/util.dart' as util;
import 'package:chaostours/enum.dart';
import 'package:chaostours/model_trackpoint.dart';

class TrackPointListView extends StatefulWidget {
  const TrackPointListView({super.key});

  @override
  State<TrackPointListView> createState() => _TrackPointListView();
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

    for (var e in TrackPointEvent.recentEvents(max: 30)) {
      _trackPointsStatusChanged.add(e);
      listView.add(createListItem(e));
    }
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
    listView.add(createListItem(event));
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
    listView[listView.length - 1] = createListItem(event);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> items = [...listView.reversed.toList()];
    return ListView(children: items);
  }

  Widget createListItem(TrackPointEvent event) {
    String duration = util.timeElapsed(event.timeStart, event.timeEnd);
    num distance = event.status == TrackingStatus.moving
        ? event.distancePath.round() / 1000
        : event.distanceStraight.round();

    String t1 = event.status == TrackingStatus.moving
        ? 'Fahren: ${distance}km in $duration'
        : 'Halt am ${util.formatDate(event.timeStart)} für $duration';

    String t2 = event.address.asString;

    String t3 = event.aliasList.isNotEmpty
        ? 'Alias ${event.aliasList.first.alias}'
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
