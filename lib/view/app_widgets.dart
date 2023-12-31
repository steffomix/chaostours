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

import 'package:chaostours/conf/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:device_calendar/device_calendar.dart';

///

import 'package:chaostours/view/widget_drawer.dart';
import 'package:chaostours/runtime_data.dart';
import 'package:chaostours/util.dart' as util;
import 'package:chaostours/calendar.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/conf/app_routes.dart';
import 'package:sprintf/sprintf.dart';

class Translate {
  //static final Logger logger = Logger.logger<Translate>();
  // static Map<String, List<Object?>> _t = {};
  static translate(String s, [List<Object?>? p]) {
    s = '§$s';
    return p == null ? s : sprintf(s, p);
  }
}

String translate(String s, [List<Object?>? p]) {
  return Translate.translate(s, p);
}

///
///
///
///
///
///
class AppWidgets {
  static final Logger logger = Logger.logger<AppWidgets>();

  static Widget materialApp(BuildContext context) {
    return MaterialApp(
      key: RuntimeData.globalKey,
      debugShowCheckedModeBanner: false,
      //themeMode: ThemeMode.system,
      title: 'Chaos Tours',
      initialRoute: AppRoutes.welcome.route,
      routes: AppRoutes.routes,
      // Theme config for FlexColorScheme version 7.3.x. Make sure you use
      // same or higher package version, but still same major version. If you
      // use a lower package version, some properties may not be supported.
      // In that case remove them after copying this theme to your app.
      theme: FlexThemeData.light(
        scheme: FlexScheme.amber,
        surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
        blendLevel: 7,
        subThemesData: const FlexSubThemesData(
          blendOnLevel: 10,
          blendOnColors: false,
          useTextTheme: true,
          useM2StyleDividerInM3: true,
          textButtonRadius: 5.0,
          filledButtonRadius: 5.0,
          elevatedButtonRadius: 5.0,
          outlinedButtonRadius: 5.0,
          segmentedButtonRadius: 5.0,
          fabUseShape: true,
          fabRadius: 5.0,
          chipRadius: 5.0,
          cardRadius: 5.0,
          alignedDropdown: true,
          dialogRadius: 5.0,
          useInputDecoratorThemeInDialogs: true,
        ),
        visualDensity: FlexColorScheme.comfortablePlatformDensity,
        useMaterial3: true,
        swapLegacyOnMaterial3: true,
        // To use the Playground font, add GoogleFonts package and uncomment
        fontFamily: GoogleFonts.notoSans().fontFamily,
      ),
      darkTheme: FlexThemeData.dark(
        scheme: FlexScheme.mango,
        surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
        blendLevel: 13,
        subThemesData: const FlexSubThemesData(
          blendOnLevel: 20,
          useTextTheme: true,
          useM2StyleDividerInM3: true,
          textButtonRadius: 5.0,
          filledButtonRadius: 5.0,
          elevatedButtonRadius: 5.0,
          outlinedButtonRadius: 5.0,
          segmentedButtonRadius: 5.0,
          fabUseShape: true,
          fabRadius: 5.0,
          chipRadius: 5.0,
          cardRadius: 5.0,
          alignedDropdown: true,
          dialogRadius: 5.0,
          useInputDecoratorThemeInDialogs: true,
        ),
        visualDensity: FlexColorScheme.comfortablePlatformDensity,
        useMaterial3: true,
        swapLegacyOnMaterial3: true,
        // To use the Playground font, add GoogleFonts package and uncomment
        fontFamily: GoogleFonts.notoSans().fontFamily,
      ),
// If you do not have a themeMode switch, uncomment this line
// to let the device system mode control the theme mode:
      themeMode: ThemeMode.light,
    );
  }

  static Future<void> navigate(BuildContext context, AppRoutes route,
      [Object? arguments]) async {
    Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.liveTracking.route, (Route<dynamic> route) => false);
    if (route != AppRoutes.liveTracking) {
      Navigator.pushNamed(context, route.route);
    }
  }

  static Scaffold scaffold(BuildContext context,
      {required Widget body,
      GlobalKey? key,
      String? title,
      BottomNavigationBar? navBar,
      AppBar? appBar,
      Widget? button}) {
    return Scaffold(
      key: key,
      floatingActionButton: button,
      floatingActionButtonLocation:
          button == null ? null : FloatingActionButtonLocation.centerDocked,
      appBar: appBar ?? _appBar(context, title: title),
      drawer: const WidgetDrawer(),
      body: body,
      bottomNavigationBar: navBar,
    );
  }

  static AppBar _appBar(BuildContext context, {String? title}) {
    return AppBar(title: Text(translate(title ?? 'ChaosTours')));
  }

  static BottomNavigationBar navBarCreateItem(BuildContext context,
      {required String name, required void Function() onCreate}) {
    return BottomNavigationBar(
        currentIndex: 1,
        items: [
          // new on osm
          BottomNavigationBarItem(
              icon: const Icon(Icons.add), label: 'Create new $name'),
          // 1 alphabethic
          const BottomNavigationBarItem(
              icon: Icon(Icons.cancel), label: 'Cancel'),
        ],
        onTap: (int id) {
          switch (id) {
            /// create
            case 0:
              AppWidgets.dialog(context: context, contents: [
                Text('Create new $name?')
              ], buttons: [
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.pop(context),
                ),
                TextButton(
                  onPressed: onCreate,
                  child: const Text('Yes'),
                )
              ]);
              break;
            // return
            case 1:
              Navigator.pop(context);
              break;

            default:
            //
          }
        });
  }

  static Widget bottomButton(
      {required BuildContext context,
      required Icon icon,
      required void Function() onPressed}) {
    return MaterialButton(
      onPressed: onPressed,
      color: Theme.of(context).bottomNavigationBarTheme.backgroundColor,
      padding: const EdgeInsets.all(10),
      shape: const CircleBorder(),
      //textColor: Colors.white,
      child: icon,
    );
  }

  static Widget divider({Color color = Colors.blueGrey}) {
    return Divider(thickness: 1, indent: 10, endIndent: 10, color: color);
  }

  static const Widget empty = SizedBox.shrink();

  static Widget calendar(Calendar? calendar) {
    if (calendar == null) {
      return const SizedBox.shrink();
    }
    return Text('${calendar.name} - ${calendar.accountName}');
  }

  static String timeInfo(DateTime timeStart, DateTime timeEnd) {
    var day = util.formatDate(timeStart);
    String duration = util.formatDuration(timeStart.difference(timeEnd).abs());
    return '$day\n${timeStart.hour}:${timeStart.minute}::${timeStart.second} - ${timeEnd.hour}:${timeEnd.minute}::${timeEnd.second}\nDuration: $duration';
  }

  static Widget loading(Widget info) {
    return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const SizedBox(width: 30, height: 30, child: CircularProgressIndicator()),
      info
    ]));
  }

  static Widget loadingScreen(BuildContext context, Widget info) {
    return AppWidgets.scaffold(context,
        body: loading(info), title: 'Loading...');
  }

  static Widget errorScreen(BuildContext context, Widget info) {
    return AppWidgets.scaffold(context,
        body: loading(info), title: 'What the F...!');
  }

  /// check FutureBuilder Snapshots,
  /// returns null on success
  static Widget? checkSnapshot<T>(
      BuildContext context, AsyncSnapshot<T> snapshot,
      {Widget? msg, void Function(BuildContext context, T data)? build}) {
    msg ??= const Text('');

    if (snapshot.connectionState == ConnectionState.waiting) {
      return AppWidgets.loadingScreen(context, msg);
    } else if (snapshot.hasError) {
      /// on error
      logger.error('checkSnapshot: ${snapshot.error}', StackTrace.current);
      return AppWidgets.errorScreen(
          context,
          Text(
              'AsyncViewBuilder $T build: ${snapshot.error ?? 'unknown error'}'));
    } else {
      /// no data
      if (!snapshot.hasData) {
        logger.error('checkSnapshot: No data', StackTrace.current);
        return AppWidgets.errorScreen(context, msg);
      }
      var data = snapshot.data;
      if (data != null) {
        build?.call(context, data);
      }
      return null;
    }
  }

  static Widget multiCheckbox(
      {required int id,
      required List<int> idList,
      required dynamic Function(bool? toggle) onToggle}) {
    final notifier = ValueNotifier<int>(0);
    return ValueListenableBuilder(
      valueListenable: notifier,
      builder: (context, _, child) {
        return Checkbox(
          value: idList.contains(id),
          onChanged: (bool? state) {
            bool checked = state ?? false;
            if (checked) {
              if (!idList.contains(id)) {
                idList.add(id);
              }
            } else {
              idList.removeWhere((i) => i == id);
            }
            Future.microtask(() => onToggle(state));
            notifier.value++;
          },
        );
      },
    );
  }

  static Widget checkbox(
      {required bool value, required dynamic Function(bool? state) onChanged}) {
    final notifier = ValueNotifier<int>(0);
    return ValueListenableBuilder(
      valueListenable: notifier,
      builder: (context, _, child) {
        return Checkbox(
          value: value,
          onChanged: (bool? state) async {
            await onChanged(state);
            value = state ?? false;
            notifier.value++;
          },
        );
      },
    );
  }

  static Future<void> dialog(
      {required BuildContext context,
      Widget? title,
      required List<Widget> contents,
      required List<Widget> buttons,
      bool isDismissible = false}) async {
    return await showDialog(
        barrierDismissible: isDismissible,
        barrierColor: !isDismissible ? AppColors.dialogBarrirer.color : null,
        context: context,
        builder: (contextDialog) {
          Widget content =
              Column(mainAxisSize: MainAxisSize.min, children: contents);

          content = SingleChildScrollView(child: content);

          return AlertDialog(
            title: title,
            content: content,
            actions: buttons,
          );
        });
  }

  static Widget searchTile(
      {required BuildContext context,
      required TextEditingController textController,
      required void Function(String text) onChange}) {
    return ListTile(
        //leading: const Icon(Icons.search),
        trailing: IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            textController.text = '';
            onChange('');
          },
        ),
        title: TextField(
          controller: textController,
          minLines: 1,
          maxLines: 1,
          decoration: const InputDecoration(
            isDense: true,
            label: Icon(Icons.search),
          ),
          onChanged: (value) {
            onChange(value);
          },
        ));
  }

  static Widget searchWidget(
      {required BuildContext context,
      required TextEditingController controller,
      required void Function(String value) onChange}) {
    return TextField(
      controller: controller,
      minLines: 1,
      maxLines: 1,
      decoration: const InputDecoration(
          icon: Icon(Icons.search, size: 30), border: InputBorder.none),
      onChanged: (value) {
        onChange(value);
      },
    );
  }

  /// loads calendars if not provided
  static Widget calendarSelector(
      {required BuildContext context,
      required void Function(Calendar cal) onSelect,
      Calendar? selectedCalendar,
      List<Calendar>? calendars}) {
    return FutureBuilder<List<Calendar>>(
      future: calendars == null
          ? AppCalendar().loadCalendars()
          : Future.value(calendars),
      builder: (context, snapshot) {
        return AppWidgets.checkSnapshot(context, snapshot) ??
            ListView.separated(
              separatorBuilder: (context, index) => AppWidgets.divider(),
              itemCount: snapshot.data!.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return ListTile(
                    title: const Text('Selected Calendar:'),
                    subtitle: Text(
                        '${selectedCalendar?.name ?? ' --- '}\n${selectedCalendar?.accountName ?? ''}'),
                  );
                } else {
                  var cal = snapshot.data![index - 1];
                  return ListTile(
                    title: Text(cal.name ?? 'Calendar $index'),
                    subtitle: Text(cal.accountName ?? 'Unknown account'),
                    onTap: (() async {
                      onSelect(cal);
                    }),
                  );
                }
              },
            );
      },
    );
  }
}

class NavBarWithTrash {
  bool _showActivated = true;
  bool get showActivated => _showActivated;
  BottomNavigationBar navBar(BuildContext dialogContext,
      {required String name,
      required void Function(BuildContext context) onCreate,
      required void Function(BuildContext context) onSwitch}) {
    return BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
              icon: const Icon(Icons.add), label: 'Create new $name'),
          _showActivated
              ? const BottomNavigationBarItem(
                  icon: Icon(Icons.delete), label: 'Show Deleted')
              : const BottomNavigationBarItem(
                  icon: Icon(Icons.visibility), label: 'Show Active'),
          const BottomNavigationBarItem(
              icon: Icon(Icons.cancel), label: 'Cancel'),
        ],
        onTap: (int id) async {
          if (id == 0) {
            AppWidgets.dialog(context: dialogContext, contents: [
              Text('Create new $name?')
            ], buttons: [
              TextButton(
                child: const Text('Cancel'),
                onPressed: () => Navigator.pop(dialogContext),
              ),
              TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    onCreate(dialogContext);
                  },
                  child: const Text('Yes'))
            ]);
          } else if (id == 1) {
            _showActivated = !_showActivated;
            onSwitch(dialogContext);
          } else {
            Navigator.pop(dialogContext);
          }
        });
  }
}
