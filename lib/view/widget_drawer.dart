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
  widget,
  divider;
}

class _Element {
  final String title;
  final String description;
  final AppRoutes route;
  final _MenuType type;
  final Widget widget;

  _Element(
      {required this.title,
      this.description = '',
      required this.route,
      required this.type,
      required this.widget});

  Widget render(BuildContext context) {
    switch (type) {
      case _MenuType.menu:
        return ListTile(
          title: Text(title),
          subtitle: Text(description,
              style: TextStyle(color: Theme.of(context).hintColor)),
          onTap: () {
            AppWidgets.navigate(context, route);
          },
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

      case _MenuType.widget:
        return widget;

      default:
        return const ListTile(title: Text('Menu type not found'));
    }
  }
}

class _Menu extends _Element {
  _Menu({required super.title, super.description, required super.route})
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

class _Widget extends _Element {
  _Widget({required super.widget})
      : super(
            title: '',
            description: '',
            route: AppRoutes.liveTracking,
            type: _MenuType.widget);
}

class _WidgetDrawer extends State<WidgetDrawer> {
  final List<_Element> menuItems = [
    _Header(title: 'Tracking'),
    _Menu(
        title: 'Life Tracking',
        description: 'What this App is all about.',
        route: AppRoutes.liveTracking),
    _Divider(),
    _Header(
        title: 'Assets',
        description:
            'Chaos Tours has more then just Locations and Trackpoints.'),
    _Menu(
        title: 'Alias',
        description: 'Manage your saved Locations.',
        route: AppRoutes.listAlias),
    _Menu(
        title: 'Trackpoints (todo)',
        description: 'Manage the automatic saved Trackpoints.',
        route: AppRoutes.listTrackpoints), // todo
    _Menu(
        title: 'Tasks',
        description: 'Manage your tasks for your trackpoints.',
        route: AppRoutes.listTask),
    _Menu(
        title: 'Users',
        description: 'Manage your friends and mates for your trackpoints.',
        route: AppRoutes.listUser),
    _Divider(),
    _Header(title: 'Asset Groups', description: 'Group your Tasks and Users.'),
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
        route: AppRoutes.permissions),
    _Divider(),
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
        route: AppRoutes.welcome),
    _Divider(),
    _Header(title: 'Licence'),
    _Widget(
        widget: TextButton(
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
            })),
    _Divider(),
    _Header(title: 'Credits')
  ];

  @override
  Widget build(BuildContext context) {
    var items = menuItems
        .map(
          (e) => e.render(context),
        )
        .toList();
    return Drawer(
      child: ListView(children: items),
    );
  }
}
