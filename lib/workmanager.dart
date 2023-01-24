import 'package:workmanager/workmanager.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/trackpoint.dart';
import 'package:chaostours/gps.dart';
import 'shared/shared.dart';
//

Logger logger = Logger.logger<Workmanager>();

@pragma(
    'vm:entry-point') // Mandatory if the App is obfuscated or using Flutter 3.1+
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
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
  Logger.backgroundLogger = true;
  Logger.prefix = '~~';
  Logger.logLevel = LogLevel.verbose;
  DateTime t;
  Duration d;
  int tickDuration = 20;
  int diff;
  String msg;
  while (true) {
    await Shared(SharedKeys.workmanagerLastTick)
        .save(DateTime.now().toIso8601String());
    try {
      logger.important(
          'workmanager backgroundTask::TrackPoint.startShared() deactivated!');
      //await TrackPoint.startShared();
    } catch (e, stk) {
      logger.fatal(e.toString(), stk);
    }
    await Future.delayed(Duration(seconds: tickDuration));

    /// measure real tick time
    /// and store fails into SharedKeys.workmanagerLastTick as list
    t = DateTime.parse((await Shared(SharedKeys.workmanagerLastTick).load() ??
        DateTime.now().toIso8601String()));
    diff = DateTime.now().difference(t).inSeconds;
    if (diff > tickDuration * 2) {
      // it should not take that long
      List<String> pause =
          await Shared(SharedKeys.workmanagerLastTick).loadList() ?? [];
      msg =
          'at ${t.toIso8601String()}: $diff seconds workmanager tick duration but $tickDuration expected';
      pause.add(msg);
      await Shared(SharedKeys.workmanagerLastTick).saveList(pause);
      logger.error(msg, null);
    }
  }
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
