import 'package:flutter/material.dart';
import 'package:chaostours/app_loader.dart';
import 'package:chaostours/view/app_widgets.dart';

void main() async {
  await AppLoader.preload();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AppWidgets.materialApp(context);
  }
}
