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

import 'package:chaostours/conf/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:restart_app/restart_app.dart';

///
import 'package:chaostours/database/cache.dart';
import 'package:chaostours/view/system/app_widgets.dart';

class WidgetColorSchemePicker extends StatefulWidget {
  const WidgetColorSchemePicker({super.key});

  @override
  State<WidgetColorSchemePicker> createState() => _WidgetColorSchemePicker();
}

class _WidgetColorSchemePicker extends State<WidgetColorSchemePicker> {
  final flexScheme = ValueNotifier<FlexScheme>(StaticCache.flexScheme);

  List<Widget> options = [];
  ThemeData? currentTheme;

  Future<bool> initialize() async {
    final mode = MediaQuery.of(context).platformBrightness;
    flexScheme.value = await Cache.appSettingsColorScheme
        .load<FlexScheme>(StaticCache.flexScheme);
    options.clear();
    for (var scheme in FlexScheme.values) {
      options.add(renderItem(
          scheme: scheme,
          colorScheme: mode == Brightness.light
              ? FlexColorScheme.light(scheme: scheme)
              : FlexColorScheme.dark(scheme: scheme)));
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    currentTheme = Theme.of(context);
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

  bool isCurrentTheme(FlexColorScheme scheme) {
    currentTheme ??= Theme.of(context);
    return currentTheme!.primaryColor == scheme.primary;
  }

  Widget renderItem(
      {required FlexScheme scheme, required FlexColorScheme colorScheme}) {
    return Container(
        color: colorScheme.primary,
        child: ListTile(
          trailing: ListenableBuilder(
              builder: (context, child) {
                return Radio<FlexScheme>(
                    groupValue: StaticCache.flexScheme,
                    value: scheme,
                    onChanged: (FlexScheme? scheme) async {
                      await Cache.appSettingsColorScheme
                          .save<FlexScheme>(scheme ?? StaticCache.flexScheme);
                      if (!mounted) {
                        return;
                      }
                      await AppWidgets.dialog(
                          context: context,
                          isDismissible: true,
                          title: const Text('Restart required'),
                          contents: [
                            const Text(
                                'To activate changes, the app must be restarted.')
                          ],
                          buttons: [
                            FilledButton(
                              child: const Text('Not now'),
                              onPressed: () {
                                if (mounted) {
                                  Navigator.pop(context);
                                }
                              },
                            ),
                            FilledButton(
                              child: const Text('Restart now'),
                              onPressed: () {
                                Restart.restartApp(
                                    webOrigin:
                                        AppRoutes.colorSchemePicker.route);
                              },
                            ),
                          ]);
                    });
              },
              listenable: flexScheme),
          leading: Stack(
            children: [
              Padding(
                  padding: const EdgeInsets.only(right: 10, bottom: 10),
                  child: Icon(Icons.stop, color: colorScheme.primary)),
              Padding(
                  padding: const EdgeInsets.only(left: 10, bottom: 10),
                  child: Icon(Icons.stop, color: colorScheme.secondary)),
              Padding(
                  padding: const EdgeInsets.only(right: 10, top: 10),
                  child: Icon(Icons.stop, color: colorScheme.primaryContainer)),
              Padding(
                  padding: const EdgeInsets.only(left: 10, top: 10),
                  child:
                      Icon(Icons.stop, color: colorScheme.secondaryContainer))
            ],
          ),
          title:
              Text(scheme.name, style: TextStyle(color: colorScheme.onPrimary)),
        ));
  }
}
