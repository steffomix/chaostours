import 'package:workmanager/workmanager.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/trackpoint.dart';
import 'package:chaostours/events.dart';
import 'package:chaostours/event_manager.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/model/model_trackpoint.dart';
import 'package:chaostours/model/model_task.dart';
import 'package:chaostours/model/model_alias.dart';
import 'shared_model/shared.dart';

@pragma(
    'vm:entry-point') // Mandatory if the App is obfuscated or using Flutter 3.1+
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    while (true) {
      try {
        await backgroundTask();
      } catch (e) {
        print(
            '######\nworkmanager failed with $e\nRestart in 10 seconds#######');
      }
      await Future.delayed(const Duration(seconds: 10));
    }
  });
}

logPrinter(String loggerName, LogLevel level, String msg,
    [String? stackTrace]) async {
  List<String> logParts = [
    loggerName,
    level.name,
    Uri.encodeFull(msg),
    stackTrace.toString(),
    '|'
  ];
  String old = await Shared(SharedKeys.backLog).load();
  List<String> oldList = old.split('\n');
  oldList.add(logParts.join('\t'));
  await Shared(SharedKeys.backLog).save(oldList.join('\n'));
}

Future<void> backgroundTask() async {
  Logger logger = Logger.logger<Workmanager>();
  Logger.prefix = '~~';
  Logger.logLevel = LogLevel.log;
  Logger.printer = logPrinter;
  TrackPoint();
  ModelTrackPoint.open();
  ModelAlias.open();
  ModelTask.open();
  int i = -200;
  while (true) {
    ++i;
    await Future.delayed(const Duration(seconds: 5), () async {
      GPS gps = await GPS.gps();
      EventManager.fire<EventOnGPS>(EventOnGPS(gps));
      EventManager.fire<EventOnTick>(EventOnTick());
      logger.log('$gps');
      logger.log('ModelTrackPoint length: ${ModelTrackPoint.length}');
    });
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
            true // If enabled it will post a notification whenever the task is running. Handy for debugging tasks
        );
    await Workmanager().registerOneOffTask("task-identifier", "simpleTask");
  }
}
