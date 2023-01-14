import 'package:chaostours/gps.dart';
import 'package:flutter/material.dart';
import 'model/model_trackpoint.dart';
import 'package:chaostours/shared_model/shared.dart';
import 'shared_model/gps_background_tracking.dart';
import 'shared_model/shared_model_tracking.dart';
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

class EventOnTracking {}

/// <p><b>Deprecated!</b></p>
/// moved to background tracking<br>
/// EventOnTracking
class EventOnTrackPoint {
  ModelTrackPoint tp;
  EventOnTrackPoint(this.tp);
}

class EventOnGps {
  final GPS gps;
  EventOnGps(this.gps);
}

class EventOnLog {
  final String msg;
  final StackTrace? stacktrace;
  final LogLevel level;
  EventOnLog(this.level, this.msg, [this.stacktrace]);
}
