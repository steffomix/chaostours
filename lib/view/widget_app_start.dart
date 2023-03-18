import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

///
import 'package:chaostours/globals.dart';
import 'package:chaostours/view/app_widgets.dart';

class WidgetAppStart extends StatefulWidget {
  const WidgetAppStart({Key? key}) : super(key: key);

  @override
  _WidgetAppStartState createState() => _WidgetAppStartState();
}

class _WidgetAppStartState extends State<WidgetAppStart> {
  String currentPermissionCheck = '';

  @override
  void initState() {
    checkPermissions();
    super.initState();
  }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // nothing checked at this point
    if (Globals.permissionsChecked && !Globals.permissionsOk) {
      // navigate
      Navigator.pushNamed(context, AppRoutes.permissions.route).then((_) {
        setState(() {});
      });
    }

    if (Globals.permissionsChecked && Globals.permissionsOk) {
      AppWidgets.navigate(context, AppRoutes.liveTracking);
    }

    return AppWidgets.scaffold(context,
        body: AppWidgets.loading(
            'Checking Permission "$currentPermissionCheck".'));
  }

  void checkPermissions() async {
    Map<String, Permission> pm = {
      'Foreground GPS': Permission.location,
      'Background GPS': Permission.locationAlways,
      //'Ignore Battery Optimizations': Permission.ignoreBatteryOptimizations,

      /// disabled due to always false and no way to grand this permission
      //Permission.storage,
      'External Storage and SDCard': Permission.manageExternalStorage,
      'Notification': Permission.notification,
      'Calendar': Permission.calendar,

      /// user also need to disable not-used app reset
    };
    for (var k in pm.keys) {
      currentPermissionCheck = k;
      setState(() {});
      if ((await pm[k]?.isDenied ?? false) ||
          (await pm[k]?.isPermanentlyDenied ?? false)) {
        Globals.permissionsOk = false;
        Globals.permissionsChecked = true;
        return;
      }
    }
    Globals.permissionsOk = true;
    Globals.permissionsChecked = true;
  }

  void navigate(BuildContext context) {
    Navigator.pushNamed(context, AppRoutes.liveTracking.route);
  }
}
