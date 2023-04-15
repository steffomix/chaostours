import 'package:chaostours/permission_checker.dart';
import 'package:flutter/material.dart';

///
import 'package:chaostours/view/app_widgets.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/app_loader.dart';
import 'package:chaostours/file_handler.dart';
import 'package:chaostours/logger.dart';

class AppInit extends StatefulWidget {
  const AppInit({super.key});

  @override
  State<AppInit> createState() => _AppInitState();
}

class _AppInitState extends State<AppInit> {
  static final Logger logger = Logger.logger<AppInit>();
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
    logger.error(msg, StackTrace.current);
    _msg.add(msg);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> appStart() async {
    await Future.delayed(const Duration(milliseconds: 200));
    try {
      await GPS.gps();
      try {
        await AppLoader.webKey();
      } catch (e) {
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
        if (FileHandler.storageKey == Storages.notSet) {
          throw 'No storage key set';
        }
      } catch (e) {
        route = AppRoutes.storageSettings;
        msg = 'FileHandler::storagePath error: $e';
        return;
      }
      /*
      try {
        await openDatabase(
            FileHandler.combinePath(
                FileHandler.storagePath!, 'chaostours.sqlite'),
            version: 2, onCreate: (Database db, int version) async {
          await db.execute(
              'CREATE TABLE Test (id INTEGER PRIMARY KEY, name TEXT, value INTEGER, num REAL)');
        });
      } catch (e, stk) {
        logger.error('open database $e', stk);
      }
*/
      try {
        await PermissionChecker.checkAll();
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
        await AppLoader.loadCache();
      } catch (e) {
        msg = 'Load cache failed: $e';
      }
      try {
        await AppLoader.loadDatabase();
      } catch (e) {
        msg = 'Load database failed: $e';
      }
      try {
        await AppLoader.loadAssetDatabase();
      } catch (e) {
        msg = 'Load asset database failed: $e';
      }
      try {
        await AppLoader.ticks();
      } catch (e) {
        msg = 'start app ticks failed: $e';
      }
      try {
        await AppLoader.backgroundGps();
      } catch (e) {
        msg = 'start background gps failed: $e';
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
      Future.delayed(const Duration(seconds: 2),
          () => Navigator.pushNamed(context, route!.route));
    }

    return AppWidgets.scaffold(context,
        body: AppWidgets.loading(_msg.join('\n\n')));
  }
}
