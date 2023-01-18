import 'package:permission_handler/permission_handler.dart';
import 'package:chaostours/logger.dart';

class Permissions {
  static Logger logger = Logger.logger<Permissions>();
  static Permissions? _instance;
  Permissions._() {
    try {
      Permissions.requestLocationPermission();
    } catch (e, stk) {
      logger.fatal(e.toString(), stk);
    }
    try {
      Permissions.requestNotificationPermission();
    } catch (e, stk) {
      logger.fatal(e.toString(), stk);
    }
  }
  factory Permissions() => _instance ??= Permissions._();

  static Future<void> requestNotificationPermission() async {
    final result = await Permission.notification.request();
    if (result == PermissionStatus.granted) {
      logger.log('Notification Permission GRANTED'); // ignore: avoid_print
    } else {
      logger.log('Notification Permission NOT GRANTED'); // ignore: avoid_print
    }
  }

  static Future<void> requestLocationPermission() async {
    final result = await Permission.locationAlways.request();
    if (result == PermissionStatus.granted) {
      logger.log('Location (GPS) Permission GRANTED'); // ignore: avoid_print
    } else {
      logger
          .log('Location (GPS) Permission NOT GRANTED'); // ignore: avoid_print
    }
  }
}
