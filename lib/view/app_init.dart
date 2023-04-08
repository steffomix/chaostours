import 'package:chaostours/permission_checker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:flutter/src/widgets/placeholder.dart';

///
import 'package:chaostours/view/app_widgets.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/app_loader.dart';
import 'package:chaostours/file_handler.dart';

class AppInit extends StatefulWidget {
  const AppInit({super.key});

  @override
  State<AppInit> createState() => _AppInitState();
}

class _AppInitState extends State<AppInit> {
  List<String> _msg = [];
  AppRoutes? route;

  @override
  void initState() {
    route = null;
    _msg = [];
    super.initState();
    appStart();
  }

  set msg(String msg) {
    _msg.add(msg);
    setState(() {});
  }

  Future<void> appStart() async {
    await Future.delayed(const Duration(milliseconds: 200));
    try {
      GPS gps = await GPS.gps();
      try {
        await AppLoader.webKey();
      } catch (e, stk) {
        msg = e.toString();
        return;
      }
      try {
        await AppLoader.globalSettings();
      } catch (e) {
        msg = e.toString();
        return;
      }
      try {
        await AppLoader.storageSettings();
        if (FileHandler.storagePath == null) {
          throw 'No storage path set';
        }
      } catch (e) {
        route = AppRoutes.storageSettings;
        msg = 'FileHandler::storagePath error: $e';
        return;
      }
      try {
        PermissionChecker.checkAll();
        if (!PermissionChecker.permissionsOk) {
          route = AppRoutes.permissions;
          msg = 'Permissions incomplete';
          return;
        }
      } catch (e) {
        msg = 'Fatal error during permission check';
        return;
      }
      try {
        AppLoader.loadCache();
      } catch (e) {
        msg = 'Load cache failed: $e';
        return;
      }
      try {
        AppLoader.loadDatabase();
      } catch (e) {
        msg = 'Load database failed: $e';
      }
    } catch (e) {
      route = AppRoutes.permissions;
      msg = 'No GPS Permissions';
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (route != null) {
      Future.delayed(const Duration(milliseconds: 300),
          () => Navigator.pushNamed(context, route!.route));
    }

    return AppWidgets.scaffold(context,
        body: AppWidgets.loading(_msg.join('\n\n')));
  }
}
