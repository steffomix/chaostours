import 'package:flutter/material.dart';
import 'package:chaostours/events.dart';
import 'widget/widget_trackpoints_listview.dart';
import 'widget/widget_main.dart';

// pane widgets that must not renew
enum Panes { trackPointList }

class Globals {
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
        _staticPanes[Panes.trackPointList] = const WidgetTrackPointEventList();

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
            const WidgetTrackPointEventList();
        return _mainPane!;
      //return mainPane;

      default:
        return mainPane;
    }
  }
}
