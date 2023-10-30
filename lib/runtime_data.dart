import 'package:flutter/material.dart';

class RuntimeData {
  static WidgetsBinding? widgetsFlutterBinding;
  static final GlobalKey<NavigatorState> globalKey =
      GlobalKey<NavigatorState>(debugLabel: 'Global Key');
  static BuildContext? get context => globalKey.currentContext;
}
