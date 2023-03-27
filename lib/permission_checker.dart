import 'package:permission_handler/permission_handler.dart';

class PermissionChecker {
  static bool permissionsChecked = false;
  static bool permissionsOk = false;

  static Future<bool> checkAll() async {
    bool permLocation = await Permission.location.isGranted;
    bool permLocationAlways = await Permission.locationAlways.isGranted;
    bool permIgnoreBattery =
        await Permission.ignoreBatteryOptimizations.isGranted;
    bool permManageExternalStorage =
        await Permission.manageExternalStorage.isGranted;
    bool permNotification = await Permission.notification.isGranted;
    bool permCalendar = await Permission.calendar.isGranted;
    permissionsChecked = true;
    if (permLocation &&
        permLocationAlways &&
        permIgnoreBattery &&
        permManageExternalStorage &&
        permNotification &&
        permCalendar) {
      permissionsOk = true;
      return true;
    }
    return false;
  }

  static Future<bool> checkLocation() async =>
      await Permission.locationAlways.isGranted;
  static Future<bool> checkLocationAlways() async =>
      await Permission.locationAlways.isGranted;
  static Future<bool> checkIgnoreBatteryOptimizations() async =>
      await Permission.ignoreBatteryOptimizations.isGranted;
  static Future<bool> checkManageExternalStorage() async =>
      await Permission.manageExternalStorage.isGranted;
  static Future<bool> checkNotification() async =>
      await Permission.notification.isGranted;
  static Future<bool> checkCalendar() async =>
      await Permission.calendar.isGranted;

  static Future<void> requestAll(Function callback) async {
    await Permission.location.request();
    callback();
    await Permission.locationAlways.request();
    callback();
    await Permission.storage.request();
    callback();
    await Permission.manageExternalStorage.request();
    callback();
    await Permission.notification.request();
    callback();
    await Permission.calendar.request();
    callback();
  }
}
