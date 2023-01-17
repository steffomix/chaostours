import 'package:flutter/material.dart';
//
import 'package:chaostours/gps.dart';
import 'package:chaostours/model/model_trackpoint.dart';
import 'package:chaostours/shared_model/shared.dart';
import 'package:chaostours/shared_model/shared_tracker.dart';
import 'package:chaostours/logger.dart';

class EventOnSharedKeyChanged {
  DateTime time = DateTime.now();
  SharedKeys key;
  String oldData;
  String newData;

  EventOnSharedKeyChanged(
      {required this.key, required this.oldData, required this.newData});
}

class EventOnMainPaneChanged {
  final Widget pane;
  EventOnMainPaneChanged(this.pane);
}

class EventOnTrackingStatusChanged {
  final ModelTrackPoint tp;
  EventOnTrackingStatusChanged(this.tp);
}

class EventOnTracking {
  final SharedTracker trackPoint;
  EventOnTracking(this.trackPoint);
}

/// <p><b>Deprecated!</b></p>
/// moved to background tracking<br>
/// EventOnTracking
class EventOnTrackPoint {
  ModelTrackPoint tp;
  EventOnTrackPoint(this.tp);
}

class EventOnGPS {
  final GPS gps;
  EventOnGPS(this.gps);
}

class EventOnTick {}
