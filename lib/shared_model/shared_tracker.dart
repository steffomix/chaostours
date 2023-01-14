import 'package:chaostours/events.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/model/model.dart';
import 'package:chaostours/shared_model/shared.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/event_manager.dart';
import 'package:chaostours/shared_model/shared_model_tracking.dart';

class SharedTracker {
  static Logger logger = Logger.logger<SharedTracker>();
  static SharedTracker? _instance;
  SharedTracker._() {
    EventManager.listen<EventOnGps>(onGps);
  }
  factory SharedTracker() => _instance ??= SharedTracker._();
  static SharedModelTracking? activeModel;

  void onGps(EventOnGps event) {
    GPS gps = event.gps;
    SharedModelTracking model = SharedModelTracking(gps);
    SharedModelTracking lastActiveModel = activeModel ?? model;
    activeModel = model;
  }
}
