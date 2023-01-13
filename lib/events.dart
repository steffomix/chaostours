import 'package:chaostours/gps.dart';
import 'package:flutter/material.dart';
import 'model_trackpoint.dart';
import 'package:chaostours/shared.dart';

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

class EventOnTrackPoint {
  ModelTrackPoint tp;
  EventOnTrackPoint(this.tp);
}

class EventOnGps {
  final GPS gps;
  EventOnGps(this.gps);
}

class EventOnLog {
  String msg;
  StackTrace? stacktrace;
  EventOnLog(this.msg, [this.stacktrace]);
}

class EventOnLogVerbose extends EventOnLog {
  EventOnLogVerbose(String msg, [StackTrace? stacktrace])
      : super(msg, stacktrace);
}

class EventOnLogDefault extends EventOnLog {
  EventOnLogDefault(String msg, [StackTrace? stacktrace])
      : super(msg, stacktrace);
}

class EventOnLogWarn extends EventOnLog {
  EventOnLogWarn(String msg, [StackTrace? stacktrace]) : super(msg, stacktrace);
}

class EventOnLogError extends EventOnLog {
  EventOnLogError(String msg, [StackTrace? stacktrace])
      : super(msg, stacktrace);
}

class EventOnLogFatal extends EventOnLog {
  EventOnLogFatal(String msg, [StackTrace? stacktrace])
      : super(msg, stacktrace);
}
