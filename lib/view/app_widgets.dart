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

import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:device_calendar/device_calendar.dart';

///
import 'package:chaostours/util.dart' as util;
import 'package:chaostours/calendar.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/conf/app_settings.dart';
import 'package:chaostours/model/model_trackpoint.dart';
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
        scheme: FlexScheme.mango,
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
    while (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
    Navigator.pushNamed(context, route.route, arguments: arguments);
  }

  static Scaffold scaffold(BuildContext context,
      {required Widget body,
      BottomNavigationBar? navBar,
      AppBar? appBar,
      Widget? button}) {
    return Scaffold(
      floatingActionButton: button,
      floatingActionButtonLocation:
          button == null ? null : FloatingActionButtonLocation.centerDocked,
      appBar: appBar ?? _appBar(context),
      drawer: const WidgetDrawer(),
      body: body,
      bottomNavigationBar: navBar,
    );
  }

  static AppBar _appBar(BuildContext context) {
    return AppBar(title: Text(translate('ChaosTours')));
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

  static String timeInfo(DateTime timeStart, DateTime timeEnd) {
    var day = '${AppSettings.weekDays[timeStart.weekday]}. den'
        ' ${timeStart.day}.${timeStart.month}.${timeStart.year}';
    String duration = util.timeElapsed(timeStart, timeEnd, false);
    return '$day, ${timeStart.hour}:${timeStart.minute} - ${timeEnd.hour}:${timeEnd.minute}\n ($duration)';
  }

  static Widget loading(String info) {
    return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const SizedBox(width: 30, height: 30, child: CircularProgressIndicator()),
      Text(info)
    ]));
  }

  static Widget loadingScreen(BuildContext context, [String? info]) {
    return scaffold(context, body: loading(info ?? translate('Loading...')));
  }

  /// check FutureBuilder Snapshots,
  /// returns null on success
  static Widget? checkSnapshot<T>(AsyncSnapshot<T> snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return AppWidgets.loading('');
    } else if (snapshot.hasError) {
      /// on error
      var msg =
          'AsyncViewBuilder $T build: ${snapshot.error ?? 'unknown error'}';
      logger.error(msg, StackTrace.current);
      return AppWidgets.loading(msg);
    } else {
      /// no data
      if (!snapshot.hasData) {
        return AppWidgets.loading('No Data');
      }
      return null;
    }
  }

  static Widget checkboxListTile(util.CheckboxController controller) =>
      util.CheckboxController.createCheckboxListTile(controller);

  static Widget checkbox(
      {required int idReference,
      required List<int> referenceList,
      required Function(bool? toggle) onToggle}) {
    return util.CheckboxController.createCheckbox(util.CheckboxController(
        idReference: idReference,
        referenceList: referenceList,
        onToggle: onToggle));
  }

  static Future<T?> dialog<T>(
      {required BuildContext context,
      required List<Widget> contents,
      required List<Widget> buttons}) {
    var dialog = showDialog<T>(
        context: context,
        builder: (contextDialog) {
          return Dialog(
              child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    ...contents,
                    Wrap(
                        spacing: 40,
                        direction: Axis.horizontal,
                        children: buttons)
                  ])));
        });

    return dialog;
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

  static ListTile trackPointInfo(BuildContext context, ModelTrackPoint tp) {
    var alias = tp.aliasModels.map((model) => model.title);
    var tasks = tp.taskModels.map((model) => model.title);
    var users = tp.userModels.map((model) => model.title);
    return ListTile(
      title: ListBody(children: [
        Center(
            heightFactor: 2,
            child: alias.isEmpty
                ? Text('OSM Addr: ${tp.address}')
                : Text('Alias: - ${alias.join('\n- ')}')),
        Center(child: Text(AppWidgets.timeInfo(tp.timeStart, tp.timeEnd))),
        divider(),
        Text(
            'Tasks:${tasks.isEmpty ? ' -' : '\n   - ${tasks.join('\n   - ')}'}'),
        divider(),
        Text(
            'Users:${users.isEmpty ? ' -' : '\n   - ${users.join('\n   - ')}'}'),
        divider(),
        const Text('Notes:'),
        Text(tp.notes),
      ]),
      leading: IconButton(
          icon: const Icon(Icons.edit_note),
          onPressed: () {
            Navigator.pushNamed(context, AppRoutes.editTrackPoint.route,
                arguments: tp.id);
          }),
    );
  }

  /// time based recent and location based lastVisited
  static Widget renderTrackPointSearchList(
      {required BuildContext context,
      required TextEditingController textController,
      required void Function() onUpdate,
      GPS? gps}) {
    return FutureBuilder<List<ModelTrackPoint>>(
      future: ModelTrackPoint.search(textController.text),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return AppWidgets.loading('');
        } else if (snapshot.hasError) {
          logger.error(
              'renderTrackPointSearchList ${snapshot.error ?? 'unknow error'}',
              StackTrace.current);
          return AppWidgets.loading(
              'FutureBuilder Error: ${snapshot.error ?? 'unknow error'}');
        } else {
          if (snapshot.hasData) {
            var data = snapshot.data!;
            if (data.isEmpty) {
              return ListView(children: const [
                Text('\n\nNoch keine Haltepunkte erstellt')
              ]);
            } else {
              var searchWidget = ListTile(
                  subtitle: Text('Count: ${data.length}'),
                  title: AppWidgets.searchWidget(
                    context: context,
                    controller: textController,
                    onChange: (String value) {
                      if (value != textController.text) {
                        textController.text = value;
                        onUpdate();
                      }
                    },
                  ));
              return ListView.builder(
                  itemCount: data.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return searchWidget;
                    }
                    return AppWidgets.trackPointInfo(context, data[index - 1]);
                  });
            }
          } else {
            logger.warn('renderTrackPointSearchList FutureBuilder no data');
            return ListView(children: const [Text('\n\nNo Data')]);
          }
        }
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
        return AppWidgets.checkSnapshot(snapshot) ??
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

///
///
///
///
///
///
///

class SliverHeader extends SliverPersistentHeaderDelegate {
  Widget widget;
  double toolBarHeight;
  //toolBarHeight Included in both
  double closedHeight;
  double openHeight;

  SliverHeader({
    required this.widget,
    required this.toolBarHeight,
    this.closedHeight = 0,
    this.openHeight = 0,
  });

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).canvasColor,
      height: toolBarHeight + openHeight,
      child: FittedBox(
        fit: BoxFit.none,
        child: widget,
      ),
    );
  }

  @override
  double get maxExtent => toolBarHeight + openHeight;

  @override
  double get minExtent => toolBarHeight + closedHeight;

  @override
  bool shouldRebuild(SliverPersistentHeaderDelegate oldDelegate) => true;
}

///
///
///
///
///
///

class WidgetDrawer extends StatefulWidget {
  const WidgetDrawer({super.key});

  @override
  State<WidgetDrawer> createState() => _WidgetDrawer();
}

class _WidgetDrawer extends State<WidgetDrawer> {
  @override
  Widget build(BuildContext context) {
    double boxHeight = 45;
    return Drawer(
        child: Container(
            padding: const EdgeInsets.all(20),
            child: ListView(padding: EdgeInsets.zero, children: [
              SizedBox(
                  height: boxHeight, child: const Center(child: Text('\n'))),

              ///
              ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.popUntil(context, (route) => route.isFirst);
                  },
                  child: const Text('Live Tracking')),

              SizedBox(
                  height: boxHeight,
                  child: const Center(child: Text('\nAssets'))),

              ///
              ElevatedButton(
                  onPressed: () {
                    AppWidgets.navigate(context, AppRoutes.trackpoints);
                  },
                  child: const Text('Haltepunkte')),

              ///
              ElevatedButton(
                  onPressed: () {
                    AppWidgets.navigate(context, AppRoutes.listUsers);
                  },
                  child: const Text('Personal')),

              ///
              ElevatedButton(
                  onPressed: () {
                    AppWidgets.navigate(context, AppRoutes.listTasks);
                  },
                  child: const Text('Arbeiten')),

              ///
              ElevatedButton(
                  onPressed: () {
                    AppWidgets.navigate(context, AppRoutes.aliasList);
                  },
                  child: const Text('Orte (Alias)')),

              ///
              ElevatedButton(
                  onPressed: () {
                    AppWidgets.navigate(context, AppRoutes.aliasGroupList);
                  },
                  child: const Text('Groups & Calendars')),

              SizedBox(
                  height: boxHeight,
                  child: const Center(child: Text('\nEvents'))),

              ///
              ElevatedButton(
                  onPressed: () {
                    AppWidgets.navigate(context, AppRoutes.selectCalendar);
                  },
                  child: const Text('Calendar')),

              SizedBox(
                  height: boxHeight,
                  child: const Center(child: Text('\nEinstellungen'))),

              ///
              ElevatedButton(
                  onPressed: () {
                    AppWidgets.navigate(context, AppRoutes.appSettings);
                  },
                  child: const Text('Einstellungen')),

              SizedBox(
                  height: boxHeight,
                  child: const Center(child: Text('\nSystem'))),

              ///
              ElevatedButton(
                  onPressed: () {
                    AppWidgets.navigate(context, AppRoutes.permissions, 1);
                  },
                  child: const Text('Android Permissions')),

              ///
              ElevatedButton(
                  onPressed: () {
                    AppWidgets.navigate(context, AppRoutes.backgroundGps);
                  },
                  child: const Text('Cache & Background GPS')),

              ///
              ElevatedButton(
                  onPressed: () {
                    AppWidgets.navigate(context, AppRoutes.logger);
                  },
                  child: const Text('App Logger')),

              SizedBox(
                  height: boxHeight,
                  child: const Center(child: Text('\nDatenbank'))),

              ///
              ElevatedButton(
                  onPressed: () {
                    AppWidgets.navigate(context, AppRoutes.importExport);
                  },
                  child: const Text('Export / Import')),

              ///
              ElevatedButton(
                  onPressed: () {
                    AppWidgets.navigate(context, AppRoutes.databaseExplorer);
                  },
                  child: const Text('Database Explorer')),

              SizedBox(
                  height: boxHeight,
                  child: const Center(child: Text('\nColor Scheme'))),

              SizedBox(
                  height: 200,
                  child: Center(
                      child: TextButton(
                          child: Text('\n\nChaosTours\n'
                              'Lizenz: Apache 2.0\n'
                              'Copyright ©${DateTime.now().year}\n'
                              'by Stefan Brinmann\n'
                              'st.brinkmann@gmail.com'),
                          onPressed: () {
                            try {
                              launchUrl(Uri.parse(
                                  'https://www.apache.org/licenses/LICENSE-2.0.html'));
                            } catch (e) {
                              //
                            }
                          }))),
            ])));
  }
}

///
///
/// not used
///
///
///

typedef OnWidgetSizeChange = void Function(Size size);

class MeasureSizeRenderObject extends RenderProxyBox {
  Size? oldSize;
  OnWidgetSizeChange onChange;

  MeasureSizeRenderObject(this.onChange);

  @override
  void performLayout() {
    super.performLayout();

    Size newSize = child!.size;
    if (oldSize == newSize) return;

    oldSize = newSize;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      onChange(newSize);
    });
  }
}

class WidgetSizeListener extends SingleChildRenderObjectWidget {
  final OnWidgetSizeChange onChange;

  const WidgetSizeListener({
    Key? key,
    required this.onChange,
    required Widget child,
  }) : super(key: key, child: child);

  @override
  RenderObject createRenderObject(BuildContext context) {
    return MeasureSizeRenderObject(onChange);
  }

  @override
  void updateRenderObject(
      BuildContext context, covariant MeasureSizeRenderObject renderObject) {
    renderObject.onChange = onChange;
  }
}
