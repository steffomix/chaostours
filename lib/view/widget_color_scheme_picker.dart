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

import 'package:chaostours/view/app_widgets.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';

class WidgetColorSchemePicker extends StatefulWidget {
  const WidgetColorSchemePicker({super.key});

  @override
  State<WidgetColorSchemePicker> createState() => _WidgetColorSchemePicker();
}

class _WidgetColorSchemePicker extends State<WidgetColorSchemePicker> {
  final flexScheme = FlexScheme.gold;

  List<Widget> options = [];

  Future<void> initialize() async {
    final mode = MediaQuery.of(context).platformBrightness;
    for (var scheme in FlexScheme.values) {
      options.add(renderItem(
          scheme: scheme,
          colorScheme: mode == Brightness.light
              ? FlexColorScheme.light(scheme: scheme)
              : FlexColorScheme.dark(scheme: scheme)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      builder: (context, snapshot) {
        return AppWidgets.checkSnapshot(context, snapshot) ?? body();
      },
      future: initialize(),
    );
  }

  Widget body() {
    return AppWidgets.scaffold(context,
        title: 'Color Theme', body: ListView(children: options));
  }

  Widget renderItem(
      {required FlexScheme scheme, required FlexColorScheme colorScheme}) {
    return ListTile(
        leading: Stack(
          children: [
            Padding(
                padding: const EdgeInsets.only(right: 10, bottom: 10),
                child: Icon(Icons.stop, color: colorScheme.primary)),
            Padding(
                padding: const EdgeInsets.only(left: 10, bottom: 10),
                child: Icon(Icons.stop, color: colorScheme.primary))
          ],
        ),
        title: Text(scheme.name));
  }
}
