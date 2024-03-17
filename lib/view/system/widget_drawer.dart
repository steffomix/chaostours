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
import 'package:chaostours/view/system/app_widgets.dart';
import 'package:chaostours/conf/app_routes.dart';
import 'package:chaostours/channel/background_channel.dart';
import 'package:chaostours/database/cache.dart';
import 'package:chaostours/view/system/menu_renderer.dart';

class WidgetDrawer extends StatefulWidget {
  const WidgetDrawer({super.key});

  @override
  State<WidgetDrawer> createState() => _WidgetDrawer();
}

class _WidgetDrawer extends State<WidgetDrawer> {
  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
          children: MenuElement.renderMenu(context, elements: menuItems())),
    );
  }

  List<MenuElement>? _menuItems;
  List<MenuElement> menuItems() {
    return _menuItems ??= [
      CustomItem(
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
      HeaderItem(title: 'Tracking'),
      MenuItem(
          title: 'Life Tracking',
          //description: 'What this App is all about.',
          route: AppRoutes.liveTracking),
      CustomItem(
          widget: FutureBuilder(
        future: Cache.appSettingStatusStandingRequireLocation.load<bool>(false),
        initialData: false,
        builder: (context, snapshot) {
          bool enabled = snapshot.data ?? false;
          return ListTile(
              title: const Text('STOP require location'),
              leading: AppWidgets.checkbox(
                  value: enabled,
                  onChanged: (state) async {
                    bool isRunning = await BackgroundChannel.isRunning();
                    if (isRunning != state) {
                      if (state ?? false) {
                        await Cache.appSettingStatusStandingRequireLocation
                            .save<bool>(false);
                      } else {
                        await Cache.appSettingStatusStandingRequireLocation
                            .save<bool>(false);
                      }
                    }
                  }));
        },
      )),
      MenuItem(
          title: 'Trackpoints',
          description: 'Manage cour Trackpoints.',
          route: AppRoutes.listTrackpoints),
      DividerItem(),
      MenuItem(
          title: 'Calendar',
          description: 'Your recorded trackpoints in a calendar view.',
          route: AppRoutes.calendar),
      DividerItem(),
      HeaderItem(
        title: 'Assets',
      ),
      MenuItem(
          title: 'Locations',
          description: 'Manage your saved Locations.',
          route: AppRoutes.listLocation), // todo
      MenuItem(
          title: 'Tasks',
          description: 'Manage your tasks for your trackpoints.',
          route: AppRoutes.listTask),
      MenuItem(
          title: 'Users',
          description: 'Manage your friends and mates for your trackpoints.',
          route: AppRoutes.listUser),
      DividerItem(),
      HeaderItem(
          title: 'Asset groups', description: 'Group your tasks and users.'),
      MenuItem(
          title: 'Location groups',
          description: 'Here you can set your calendars',
          route: AppRoutes.listLocationGroup),
      MenuItem(
          title: 'Task Groups',
          description: 'Group your tasks into seasons.',
          route: AppRoutes.listTaskGroup),
      MenuItem(
          title: 'User Groups',
          description: 'Group your Users into teams.',
          route: AppRoutes.listUserGroup),
      DividerItem(),
      CustomItem(
          widget: ListTile(
        title: FilledButton(
          child: const Text('Device calendar'),
          onPressed: () {
            launchUrl(Uri.parse('content://com.android.calendar'));
          },
        ),
        subtitle: const Text('Open your device calendar direct from here.'),
      )),
      DividerItem(),
      HeaderItem(
          title: 'App Configuration',
          description: 'Configure Chaos Tours to fit your needs.'),
      MenuItem(
          title: 'Settings',
          description:
              'Sevaral settings. Most of them are good to go but who knows...',
          route: AppRoutes.appSettings),
      MenuItem(
          title: 'Color scheme',
          description: 'Style your app.',
          route: AppRoutes.colorSchemePicker),
      MenuItem(
          title: 'Permissions',
          description:
              'This app needs tons of permissions to unfold its full potential.',
          route: AppRoutes.permissions,
          routeArguments: ''),
      MenuItem(
          title: 'Import/Export database',
          description: 'Backup and restore your data',
          route: AppRoutes.importExport,
          routeArguments: ''),
      DividerItem(),
      HeaderItem(
          title: 'App backstage',
          description: 'Explore your saved data\nhot\'n raw from backstage.'),
      MenuItem(
          title: 'Database explorer',
          description: 'Your saved data presented in a bloody raw style.',
          route: AppRoutes.databaseExplorer),
      DividerItem(),
      CustomItem(
          widget: ListTile(
        title: FilledButton(
          child: const Text('Support'),
          onPressed: () {
            launchUrl(
                Uri.parse('https://github.com/steffomix/chaostours/issues'));
          },
        ),
        subtitle: const Text(
            'Opens the developer platform and issue tracker on github.com where you can view the source code, file an issue or a future request.'),
      )),
      CustomItem(
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

      DividerItem(),
      CustomItem(
          widget: ListTile(
        title: Text('Licence OpenStreetMap',
            style: Theme.of(context).textTheme.titleLarge),
        subtitle: TextButton(
            child: const Text('OpenStreetmap\n'
                'This app uses the free service from openstreetmap.org'
                ' for map display and reverse address lookup.\n'
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
      DividerItem(),
      HeaderItem(title: 'Credits')
    ];
  }
}
