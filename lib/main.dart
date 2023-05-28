/*
Copyright 2023 Stefan Brinkmann <st.brinkmann@gmail.com>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

///
import 'package:chaostours/conf/theme_provider.dart';
import 'package:chaostours/conf/app_theme_data.dart';
import 'package:chaostours/app_loader.dart';
import 'package:chaostours/view/app_widgets.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppLoader.preload();
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(
        AppThemeData.theme, // Set the initial theme
      ),
      // ignore: prefer_const_constructors
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AppWidgets.materialApp(context);
  }
}
