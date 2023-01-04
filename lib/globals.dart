import 'package:flutter/material.dart';
//
import 'package:chaostours/events.dart';
import 'package:chaostours/widget/widget_trackpoints_listview.dart';
import 'package:chaostours/widget/widget_main.dart';

// pane widgets that must not renew
enum Panes { trackPointList }

enum OsmLookup { never, onStatus, always }

class Globals {
  static String version = '';
  static const bool debugMode = false;
  static double distanceTreshold = 100; //meters
  static OsmLookup osmLookup = OsmLookup.onStatus;

  // durations and distances
  // skip status check for given time to prevent ugly things
  static Duration get waitTimeAfterStatusChanged {
    return debugMode ? const Duration(seconds: 1) : const Duration(minutes: 1);
  }

  // stop time needed to trigger stop
  static Duration get stopTimeTreshold {
    return debugMode ? const Duration(seconds: 10) : const Duration(minutes: 3);
  }

  // check status interval
  static Duration get trackPointTickTime {
    return debugMode ? const Duration(seconds: 2) : const Duration(seconds: 20);
  }

  ///
  /// App from widget_main
  ///
  static App? _app;
  static App get app => _app ??= const App();

  static final Map<Panes, Widget?> _staticPanes = {
    Panes.trackPointList: null,
  };

  ///
  /// default main pane
  ///
  static Widget? _mainPane;
  static Widget get mainPane {
    _mainPane ??=
        _staticPanes[Panes.trackPointList] = const WidgetModelTrackPointList();

    return _mainPane!;
  }

  static set mainPane(Widget pane) {
    _mainPane = pane;
    eventBusMainPaneChanged.fire(pane);
  }

  // panes that doesn't renew over app lifetime
  static Widget pane(Panes pane) {
    switch (pane) {
      case Panes.trackPointList:
        // same as mainPane but from Map _staticPanes
        _mainPane = _staticPanes[Panes.trackPointList] ??=
            const WidgetModelTrackPointList();
        return _mainPane!;
      //return mainPane;

      default:
        return mainPane;
    }
  }
}
