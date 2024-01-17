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

///
import 'package:chaostours/view/system/app_widgets.dart';
import 'package:chaostours/conf/app_routes.dart';

enum MenuType {
  menu,
  header,
  custom,
  divider;
}

abstract class MenuElement {
  final String title;
  final String description;
  final AppRoutes route;
  final dynamic routeArguments;
  final MenuType type;
  final Widget widget;

  MenuElement(
      {required this.title,
      this.description = '',
      required this.route,
      this.routeArguments,
      required this.type,
      required this.widget});

  static List<Widget> renderMenu(BuildContext context,
      {required List<MenuElement> elements}) {
    return elements
        .map(
          (e) => e.render(context),
        )
        .toList();
  }

  Widget render(BuildContext context) {
    switch (type) {
      case MenuType.menu:
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

      case MenuType.header:
        return ListTile(
            subtitle: Text(description,
                style: TextStyle(color: Theme.of(context).hintColor)),
            title: Center(
                child: Text(title,
                    style: Theme.of(context).textTheme.titleLarge)));

      case MenuType.divider:
        return AppWidgets.divider();

      case MenuType.custom:
        return widget;

      default:
        return const ListTile(title: Text('Menu type not found'));
    }
  }
}

class MenuItem extends MenuElement {
  MenuItem(
      {required super.title,
      super.description,
      required super.route,
      super.routeArguments})
      : super(type: MenuType.menu, widget: const Text(''));
}

class HeaderItem extends MenuElement {
  HeaderItem({required super.title, super.description})
      : super(
            route: AppRoutes.liveTracking,
            type: MenuType.header,
            widget: const Text(''));
}

class DividerItem extends MenuElement {
  DividerItem()
      : super(
            title: '',
            description: '',
            route: AppRoutes.liveTracking,
            type: MenuType.divider,
            widget: const Text(''));
}

class CustomItem extends MenuElement {
  CustomItem({required super.widget})
      : super(
            title: '',
            description: '',
            route: AppRoutes.liveTracking,
            type: MenuType.custom);
}
