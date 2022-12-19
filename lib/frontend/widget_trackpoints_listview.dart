import 'dart:async';
import 'package:flutter/material.dart';
import 'package:chaostours/events.dart';
import '../log.dart';

class TrackPointListView extends StatefulWidget {
  const TrackPointListView({super.key});

  @override
  State<TrackPointListView> createState() => _TrackPointListView();
}

class _TrackPointListView extends State<TrackPointListView> {
  static final List<TrackingStatusChangedEvent> _trackPoints = [];
  static final List<Widget> listView = [];
  static StreamSubscription? _trackingStatusListener;

  _TrackPointListView() {
    _trackingStatusListener ??= trackingStatusEvents
        .on<TrackingStatusChangedEvent>()
        .listen(onTrackingStatusChanged);
  }

  void onTrackingStatusChanged(TrackingStatusChangedEvent event) {
    listView.add(trackPoint(event));

    setState(() {});
  }

  Text trackPoint(TrackingStatusChangedEvent event) {
    String title = event.trackPoint.address.asString;
    return Text('title $title');
  }

  @override
  Widget build(BuildContext context) {
    logFatal('build ListView ${listView.length}');
    //return ListView(children: const [Text('testa'), Text('test2')]);
    //return Text('trackPointListview...${_trackPoints.length}');
    return listView.length < 2
        ? Text('waiting ${listView.length}')
        : ListView(children: listView);
  }
}
