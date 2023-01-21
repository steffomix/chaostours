import 'package:workmanager/workmanager.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/trackpoint.dart';
import 'package:chaostours/event_manager.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/model/model_trackpoint.dart';
import 'package:chaostours/model/model_task.dart';
import 'package:chaostours/model/model_alias.dart';
import 'shared/shared.dart';
////
import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
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
  TrackPoint();
  ModelTrackPoint.open();
  ModelAlias.open();
  ModelTask.open();
  while (true) {
    await Future.delayed(const Duration(seconds: 5));
    try {
      Shared sharedAlias = Shared(SharedKeys.modelAlias);
      List<String> sharedAliasList = [];
      String dump = ModelAlias.dump();
      for (var i = 0; i < 500; i++) {
        sharedAliasList.addAll(dump.split('\n'));
      }
      sharedAlias.saveList(sharedAliasList);
      ////
      String filename = 'test.tsv';
      Directory appDir = await getApplicationDocumentsDirectory();
      String p = join(appDir.path, /*'chaostours',*/ filename);
      final file = File(p);
      await file.writeAsString(sharedAliasList.join('\n'),
          mode: FileMode.append);
      int fileLength = file.lengthSync();

      ///

      Shared shared = Shared(SharedKeys.counterWorkmanager);
      int counter = await shared.loadInt() ?? 0;
      counter++;
      await shared.saveInt(counter);

      GPS gps = await GPS.gps();
      await ModelTrackPoint.open();
      EventManager.fire<EventOnGPS>(EventOnGPS(gps));
      logger.log('ModelTrackPoint length: ${ModelTrackPoint.length}');
    } catch (e, stk) {
      logger.fatal(e.toString(), stk);
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
