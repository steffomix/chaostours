/*
import 'package:workmanager/workmanager.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/trackpoint.dart';
import 'package:chaostours/gps.dart';
import 'shared/shared.dart';
//

@pragma(
    'vm:entry-point') // Mandatory if the App is obfuscated or using Flutter 3.1+
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    Logger logger = Logger.logger<Workmanager>();
    Logger.backgroundLogger = true;
    Logger.prefix = '~~';
    while (true) {
      try {
        await backgroundTask();
      } catch (e, stk) {
        logger.fatal('Workmanager failed with $e', stk);
      }
      await Future.delayed(const Duration(seconds: 10));
    }
  });
}

Future<void> backgroundTask() async {
  Logger logger = Logger.logger<Workmanager>();
  Logger.backgroundLogger = true;
  Logger.prefix = '~~~';
  logger.log('backgroundTask');
}

class WorkManager {
  static WorkManager? _instance;
  WorkManager._() {
    initialize();
  }
  factory WorkManager() => _instance ??= WorkManager._();

  initialize() async {
    await Workmanager().cancelAll();

    //await AppLoader.preload();
    //Logger.logLevel = LogLevel.log;
    await Workmanager().initialize(
        callbackDispatcher, // The top level function, aka callbackDispatcher
        isInDebugMode:
            false // If enabled it will post a notification whenever the task is running. Handy for debugging tasks
        );
    await Workmanager()
        .registerOneOffTask("com.stefanbrinkmann.chaostours.background", "gps");
  }
}
*/
