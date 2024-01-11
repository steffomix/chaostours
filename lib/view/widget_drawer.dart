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

import 'package:chaostours/channel/background_channel.dart';
import 'package:chaostours/database/cache.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

///
import 'package:chaostours/view/app_widgets.dart';
import 'package:chaostours/conf/app_routes.dart';

class WidgetDrawer extends StatefulWidget {
  const WidgetDrawer({super.key});

  @override
  State<WidgetDrawer> createState() => _WidgetDrawer();
}

enum _MenuType {
  menu,
  header,
  custom,
  divider;
}

class _Element {
  final String title;
  final String description;
  final AppRoutes route;
  final dynamic routeArguments;
  final _MenuType type;
  final Widget widget;

  _Element(
      {required this.title,
      this.description = '',
      required this.route,
      this.routeArguments,
      required this.type,
      required this.widget});

  Widget render(BuildContext context) {
    switch (type) {
      case _MenuType.menu:
        return ListTile(
          title: FilledButton(
            child: Text(title),
            onPressed: () {
              AppRoutes.navigate(context, route, routeArguments);
            },
          ),
          subtitle: Text(description,
              style: TextStyle(color: Theme.of(context).hintColor)),
        );

      case _MenuType.header:
        return ListTile(
            subtitle: Text(description,
                style: TextStyle(color: Theme.of(context).hintColor)),
            title: Center(
                child: Text(title,
                    style: Theme.of(context).textTheme.titleLarge)));

      case _MenuType.divider:
        return AppWidgets.divider();

      case _MenuType.custom:
        return widget;

      default:
        return const ListTile(title: Text('Menu type not found'));
    }
  }
}

class _Menu extends _Element {
  _Menu(
      {required super.title,
      super.description,
      required super.route,
      super.routeArguments})
      : super(type: _MenuType.menu, widget: const Text(''));
}

class _Header extends _Element {
  _Header({required super.title, super.description})
      : super(
            route: AppRoutes.liveTracking,
            type: _MenuType.header,
            widget: const Text(''));
}

class _Divider extends _Element {
  _Divider()
      : super(
            title: '',
            description: '',
            route: AppRoutes.liveTracking,
            type: _MenuType.divider,
            widget: const Text(''));
}

class _Custom extends _Element {
  _Custom({required super.widget})
      : super(
            title: '',
            description: '',
            route: AppRoutes.liveTracking,
            type: _MenuType.custom);
}

class _WidgetDrawer extends State<WidgetDrawer> {
  @override
  Widget build(BuildContext context) {
    var items = menuItems()
        .map(
          (e) => e.render(context),
        )
        .toList();
    return Drawer(
      child: ListView(children: items),
    );
  }

  List<_Element>? _menuItems;
  List<_Element> menuItems() {
    return _menuItems ??= [
      _Custom(
          widget: FutureBuilder(
        future: Cache.appSettingBackgroundTrackingEnabled.load<bool>(false),
        initialData: false,
        builder: (context, snapshot) {
          bool enabled = snapshot.data ?? false;
          return ListTile(
              title: const Text('Background tracking'),
              leading: AppWidgets.checkbox(
                  value: enabled,
                  onChanged: (state) async {
                    bool isRunning = await BackgroundChannel.isRunning();
                    if (isRunning != state) {
                      if (state ?? false) {
                        BackgroundChannel.start();
                      } else {
                        BackgroundChannel.stop();
                      }
                      await Cache.appSettingBackgroundTrackingEnabled
                          .save<bool>(enabled);
                    }
                  }));
        },
      )),
      _Header(title: 'Tracking'),
      _Menu(
          title: 'Life Tracking',
          //description: 'What this App is all about.',
          route: AppRoutes.liveTracking),
      _Custom(
          widget: FutureBuilder(
        future: Cache.appSettingStatusStandingRequireAlias.load<bool>(false),
        initialData: false,
        builder: (context, snapshot) {
          bool enabled = snapshot.data ?? false;
          return ListTile(
              title: const Text('STOP require Alias'),
              leading: AppWidgets.checkbox(
                  value: enabled,
                  onChanged: (state) async {
                    bool isRunning = await BackgroundChannel.isRunning();
                    if (isRunning != state) {
                      if (state ?? false) {
                        await Cache.appSettingStatusStandingRequireAlias
                            .save<bool>(false);
                      } else {
                        await Cache.appSettingStatusStandingRequireAlias
                            .save<bool>(false);
                      }
                    }
                  }));
        },
      )),
      _Menu(
          title: 'Trackpoints',
          description: 'Manage the automatic saved Trackpoints.',
          route: AppRoutes.listTrackpoints),
      _Divider(),
      _Header(
          title: 'Assets',
          description:
              'Chaos Tours has more then just Locations and Trackpoints.'),
      _Menu(
          title: 'Location Alias',
          description: 'Manage your saved Locations.',
          route: AppRoutes.listAlias), // todo
      _Menu(
          title: 'Tasks',
          description: 'Manage your tasks for your trackpoints.',
          route: AppRoutes.listTask),
      _Menu(
          title: 'Users',
          description: 'Manage your friends and mates for your trackpoints.',
          route: AppRoutes.listUser),
      _Divider(),
      _Header(
          title: 'Asset Groups', description: 'Group your Tasks and Users.'),
      _Menu(
          title: 'Alias Groups',
          description: 'Here you can set your Calendars',
          route: AppRoutes.listAliasGroup),
      _Menu(
          title: 'Task Groups',
          description: 'Group your Tasks into Seasons.',
          route: AppRoutes.listTaskGroup),
      _Menu(
          title: 'User Groups',
          description: 'Group your Users into Teams.',
          route: AppRoutes.listUserGroup),
      _Divider(),
      _Header(
          title: 'App Configuration',
          description: 'Configure Chaos Tours to fit your needs.'),
      _Menu(
          title: 'Settings',
          description:
              'Sevaral Settings. Most of them are good to go but who knows...',
          route: AppRoutes.appSettings),
      _Menu(
          title: 'Color Scheme (todo)',
          description: 'Style your App.',
          route: AppRoutes.appSettings),
      _Menu(
          title: 'Permissions',
          description:
              'This App needs tons of permissions to unfold its full potential.',
          route: AppRoutes.welcome,
          routeArguments: ''),
      _Menu(
          title: 'Import/Export Database',
          description: 'Backup and restore your Data',
          route: AppRoutes.importExport,
          routeArguments: ''),
      _Divider(),
      /* 
    _Header(
        title: 'External sources',
        description: 'Import Locations from the Web or as Text File.'),
    _Menu(
        title: 'Import locations from Web (Todo)', route: AppRoutes.listAlias),
    _Menu(
        title: 'Import locations from File (Todo)', route: AppRoutes.listAlias),
    _Menu(
        title: 'Import & Export',
        description: 'Make Data Backups ot import Data from friends.',
        route: AppRoutes.importExport),
    _Divider(), */
      _Header(
          title: 'App Backstage',
          description: 'Explore your saved Data\nhot\'n raw from Backstage.'),
      _Menu(
          title: 'Database Explorer',
          description: 'Your saved Data presented in a bloody raw style.',
          route: AppRoutes.databaseExplorer),
      _Menu(
          title: 'Welcome Page',
          description: 'App initialization routines and permission checks.',
          route: AppRoutes.welcome,
          routeArguments: 1),
      _Divider(),
      _Custom(
          widget: ListTile(
        title: Text('Licence ChaosTours',
            style: Theme.of(context).textTheme.titleLarge),
        subtitle: TextButton(
            child: Text('ChaosTours\n'
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
            }),
      )),

      _Divider(),
      _Custom(
          widget: ListTile(
        title: Text('Licence OpenStreetMap',
            style: Theme.of(context).textTheme.titleLarge),
        subtitle: TextButton(
            child: const Text('OpenStreetmap\n'
                'This App uses the free service from OpenStreetMap.org'
                ' for Mmp display and reverse address lookup.\n'
                'Tap on this text to get to:\n'
                'www.openstreetmap.org/copyright'),
            onPressed: () {
              try {
                launchUrl(Uri.parse('https://www.openstreetmap.org/copyright'));
              } catch (e) {
                //
              }
            }),
      )),
      _Divider(),
      _Header(title: 'Credits')
    ];
  }
}
