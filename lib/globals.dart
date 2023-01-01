import 'package:flutter/material.dart';
import 'package:chaostours/widget/widget_main.dart';

enum Global { widgetTrackList, widgetTrackPointTask }

class Globals {
  static App? _app;
  static App get app => _app ??= const App();
  static set mainPane(Widget pane) => App.mainPane = pane;
  static Widget get mainPane => App.mainPane;
}
