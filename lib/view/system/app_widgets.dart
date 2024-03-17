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

import 'package:app_settings/app_settings_platform_interface.dart';
import 'package:calendar_view/calendar_view.dart';
import 'package:chaostours/database/cache.dart';
import 'package:chaostours/model/model_location_group.dart';
import 'package:chaostours/model/model_task_group.dart';
import 'package:chaostours/model/model_trackpoint.dart';
import 'package:chaostours/model/model_user_group.dart';
import 'package:flutter/material.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:device_calendar/device_calendar.dart';

///

import 'package:chaostours/conf/app_colors.dart';
import 'package:chaostours/statistics/asset_statistics.dart';
import 'package:chaostours/model/model_task.dart';
import 'package:chaostours/model/model_user.dart';
import 'package:chaostours/view/system/widget_drawer.dart';
import 'package:chaostours/util.dart' as util;
import 'package:chaostours/calendar.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/conf/app_routes.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sprintf/sprintf.dart';

class Translate {
  //static final Logger logger = Logger.logger<Translate>();
  // static Map<String, List<Object?>> _t = {};
  static translate(String s, [List<Object?>? p]) {
    //s = '$s';
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

  static final calendarEventController = EventController<ModelTrackPoint>();

  static Widget materialApp(BuildContext context) {
    return CalendarControllerProvider(
        controller: calendarEventController,
        child: MaterialApp(
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
            scheme: StaticCache.flexScheme, //FlexScheme.gold,
            surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
            blendLevel: 13,
            subThemesData: const FlexSubThemesData(
              blendOnLevel: 20,
              blendOnColors: true,
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
            visualDensity: null, //FlexColorScheme.comfortablePlatformDensity,
            useMaterial3: true,
            swapLegacyOnMaterial3: true,
            // To use the Playground font, add GoogleFonts package and uncomment
            fontFamily: GoogleFonts.openSans().fontFamily,
          ),
          darkTheme: FlexThemeData.dark(
            scheme: StaticCache.flexScheme,
            surfaceMode: FlexSurfaceMode
                .highScaffoldLowSurface, // .levelSurfacesLowScaffold,
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
            fontFamily: GoogleFonts.openSans().fontFamily,
          ),
// If you do not have a themeMode switch, uncomment this line
// to let the device system mode control the theme mode:
          themeMode: ThemeMode.system,
        ));
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
              onCreate();
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

  static Future<bool> requestLocation(BuildContext context) async {
    bool permDenied = await Permission.location.isPermanentlyDenied;
    if (!permDenied) {
      Permission.location.request();
    } else if (context.mounted) {
      await AppWidgets.dialog(context: context, contents: [
        const Text(
            'You have permanently denied Location service for this app \n'
            'and must go to the App Settings of your device to enable ist again:')
      ], buttons: [
        FilledButton(
          child: const Text('Go to App Settings'),
          onPressed: () {
            AppSettingsPlatform.instance.openAppSettings();
          },
        )
      ]);
    }
    return await Permission.location.isGranted;
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
    var day = util.formatDateTime(timeStart);
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
      List<Widget> contents = const [],
      List<Widget> buttons = const [],
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

  static Future<ModelUser?> createUser(BuildContext context) async {
    final controller = TextEditingController(text: '');
    final nextId = (await ModelUser.count()) + 1;
    ModelUser? newModel;
    if (!context.mounted) {
      return null;
    }
    await AppWidgets.dialog(
        isDismissible: true,
        context: context,
        title: const Text('Create new User'),
        contents: [
          Padding(
              padding: const EdgeInsets.all(10),
              child: TextField(
                decoration: const InputDecoration(label: Text('Username')),
                controller: controller,
              )),
        ],
        buttons: [
          FilledButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () async {
                newModel = await ModelUser(
                        title: controller.text.isEmpty
                            ? 'User #$nextId'
                            : controller.text)
                    .insert();
                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text('Create')),
        ]);
    return newModel;
  }

  static Future<ModelTask?> createTask(BuildContext context) async {
    final controller = TextEditingController(text: '');
    final nextId = (await ModelTask.count()) + 1;
    ModelTask? newModel;
    if (!context.mounted) {
      return null;
    }
    await AppWidgets.dialog(
        isDismissible: true,
        context: context,
        title: const Text('Create new Task'),
        contents: [
          Padding(
              padding: const EdgeInsets.all(10),
              child: TextField(
                decoration: const InputDecoration(label: Text('Taskname')),
                controller: controller,
              )),
        ],
        buttons: [
          FilledButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () async {
                newModel = await ModelTask(
                        title: controller.text.isEmpty
                            ? 'Task #$nextId'
                            : controller.text)
                    .insert();
                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text('Create')),
        ]);
    return newModel;
  }

  static Future<ModelLocationGroup?> createLocationGroup(
      BuildContext context) async {
    final controller = TextEditingController(text: '');
    final nextId = (await ModelLocationGroup.count()) + 1;
    ModelLocationGroup? newModel;
    if (!context.mounted) {
      return null;
    }
    await AppWidgets.dialog(
        isDismissible: true,
        context: context,
        title: const Text('Create new location group'),
        contents: [
          Padding(
              padding: const EdgeInsets.all(10),
              child: TextField(
                decoration: const InputDecoration(label: Text('Group name')),
                controller: controller,
              )),
        ],
        buttons: [
          FilledButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () async {
                newModel = await ModelLocationGroup(
                        title: controller.text.isEmpty
                            ? 'Location group #$nextId'
                            : controller.text)
                    .insert();
                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text('Create')),
        ]);
    return newModel;
  }

  static Future<ModelTaskGroup?> createTaskGroup(BuildContext context) async {
    final controller = TextEditingController(text: '');
    final nextId = (await ModelTaskGroup.count()) + 1;
    ModelTaskGroup? newModel;
    if (!context.mounted) {
      return null;
    }
    await AppWidgets.dialog(
        isDismissible: true,
        context: context,
        title: const Text('Create new task group'),
        contents: [
          Padding(
              padding: const EdgeInsets.all(10),
              child: TextField(
                decoration: const InputDecoration(label: Text('Group name')),
                controller: controller,
              )),
        ],
        buttons: [
          FilledButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () async {
                newModel = await ModelTaskGroup(
                        title: controller.text.isEmpty
                            ? 'Task group #$nextId'
                            : controller.text)
                    .insert();
                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text('Create')),
        ]);
    return newModel;
  }

  static Future<ModelUserGroup?> createUserGroup(BuildContext context) async {
    final controller = TextEditingController(text: '');
    final nextId = (await ModelUserGroup.count()) + 1;
    ModelUserGroup? newModel;
    if (!context.mounted) {
      return null;
    }
    await AppWidgets.dialog(
        isDismissible: true,
        context: context,
        title: const Text('Create new user group'),
        contents: [
          Padding(
              padding: const EdgeInsets.all(10),
              child: TextField(
                decoration: const InputDecoration(label: Text('Group name')),
                controller: controller,
              )),
        ],
        buttons: [
          FilledButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () async {
                newModel = await ModelUserGroup(
                        title: controller.text.isEmpty
                            ? 'User group #$nextId'
                            : controller.text)
                    .insert();
                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text('Create')),
        ]);
    return newModel;
  }

  static void statistics(BuildContext context,
      {required AssetStatistics stats,
      required Future<AssetStatistics> Function(DateTime start, DateTime end)
          reload}) {
    final notify = ValueNotifier(stats);
    final startBounds = util
        .removeTime(stats.firstVisited.subtract(const Duration(days: 1000)));
    final endBounds =
        util.removeTime(stats.lastVisited.add(const Duration(days: 1000)));

    Widget contents = ValueListenableBuilder(
      valueListenable: notify,
      builder: (context, value, child) {
        stats = value;

        return Column(children: [
          TextButton(
              child: const Text('Reset dates'),
              onPressed: () async {
                notify.value = await reload(startBounds, endBounds);
              }),
          SingleChildScrollView(
              controller: ScrollController(),
              scrollDirection: Axis.horizontal,
              child: DataTable(showBottomBorder: true, columns: const [
                DataColumn(label: SizedBox.shrink()),
                DataColumn(label: Text(''))
              ], rows: [
                DataRow(cells: [
                  const DataCell(Text('First Trackpoint')),
                  DataCell(FilledButton(
                    child: Text(util.formatDateTime(stats.firstVisited)),
                    onPressed: () async {
                      final date = await showDatePicker(
                          helpText: 'Select start',
                          context: context,
                          firstDate: startBounds,
                          lastDate: endBounds);
                      notify.value = await reload(
                          util.removeTime(date ?? stats.firstVisited),
                          stats.lastVisited);
                    },
                  ))
                ]),
                DataRow(cells: [
                  const DataCell(Text('Last Trackpoint')),
                  DataCell(FilledButton(
                    child: Text(util.formatDateTime(stats.lastVisited)),
                    onPressed: () async {
                      notify.value = await reload(
                        stats.firstVisited,
                        util.removeTime(await showDatePicker(
                                helpText: 'Select end',
                                context: context,
                                firstDate: startBounds,
                                lastDate: endBounds) ??
                            stats.lastVisited),
                      );
                    },
                  ))
                ]),
                DataRow(cells: [
                  const DataCell(Text('Times visited')),
                  DataCell(Text(stats.count.toString()))
                ]),
                DataRow(cells: [
                  const DataCell(Text('Duration Min.')),
                  DataCell(Text(util.formatDuration(stats.durationMin)))
                ]),
                DataRow(cells: [
                  const DataCell(Text('Duration Max.')),
                  DataCell(Text(util.formatDuration(stats.durationMax)))
                ]),
                DataRow(cells: [
                  const DataCell(Text('Duration Avg.')),
                  DataCell(Text(util.formatDuration(stats.durationAverage)))
                ]),
                DataRow(cells: [
                  const DataCell(Text('Duration Total')),
                  DataCell(Text(util.formatDuration(stats.durationTotal)))
                ]),
              ]))
        ]);
      },
    );

    AppWidgets.dialog(
        isDismissible: true,
        context: context,
        title: const Text('Statistics'),
        contents: [
          contents
        ],
        buttons: [
          TextButton(
            child: const Icon(Icons.copy),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: '''
Location:\t ${stats.model.title}

First Visited:\t ${util.formatDateTime(stats.firstVisited)}
Last Visited:\t ${util.formatDateTime(stats.lastVisited)}
Times Visited:\t ${stats.count}

Min. Duration:\t ${util.formatDuration(stats.durationMin)}
Max. Duration:\t ${util.formatDuration(stats.durationMax)}
Avg. Duration:\t ${util.formatDuration(stats.durationAverage)}
Duration Total:\t ${util.formatDuration(stats.durationTotal)}

Location Description:\t ${stats.model.description}
'''));
              Navigator.pop(context);
            },
          ),
          TextButton(
            child: const Text('OK'),
            onPressed: () {
              Navigator.pop(context);
            },
          )
        ]);
  }
}

class NavBarWithBin {
  bool _showActivated = true;
  bool get showActivated => _showActivated;
  BottomNavigationBar navBar(BuildContext context,
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
            onCreate(context);
            /* 
            AppWidgets.dialog(context: context, contents: [
              Text('Create new $name?')
            ], buttons: [
              TextButton(
                child: const Text('Cancel'),
                onPressed: () => Navigator.pop(context),
              ),
              TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    onCreate(context);
                  },
                  child: const Text('Yes'))
            ]); */
          } else if (id == 1) {
            _showActivated = !_showActivated;
            onSwitch(context);
          } else {
            Navigator.pop(context);
          }
        });
  }
}
