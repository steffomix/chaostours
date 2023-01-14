import 'package:chaostours/events.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/model/model.dart';
import 'package:chaostours/shared_model/shared.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/event_manager.dart';
import 'package:chaostours/shared_model/shared_model_tracking.dart';
import 'package:chaostours/trackpoint.dart';
import 'package:chaostours/model/model_trackpoint.dart';

/// save only (provide) data for Widget TrackPointListView
class SharedTracker {
  static Logger logger = Logger.logger<SharedTracker>();
  static SharedTracker? _instance;
  static List<ModelTrackPoint> recentTrackPoints = [];
  SharedTracker._() {
    EventManager.listen<EventOnTrackPoint>(onTrackPoint);
    EventManager.listen<EventOnTrackingStatusChanged>(onTrackingStatusChanged);
    provideRecentTrackpoints();
  }
  factory SharedTracker() => _instance ??= SharedTracker._();

  void onTrackPoint(EventOnTrackPoint event) async {
    await Shared(SharedKeys.activeTrackpoint).save(event.tp.toSharedString());
  }

  Future<void> onTrackingStatusChanged(
      EventOnTrackingStatusChanged event) async {
    await Shared(SharedKeys.activeTrackpoint).save(event.tp.toSharedString());
    // the trackpoint is already saved at this point
    // so that we have to update the recent list
    await provideRecentTrackpoints();
  }

  /// load models from ModelTrackPoint and save to shared RecentTrackpoints
  /// provided for widgetListView that is running in foreground
  Future<void> provideRecentTrackpoints() async {
    List<ModelTrackPoint> recentModels = ModelTrackPoint.recentTrackPoints();
    List<String> recentList = [];
    for (var m in recentModels) {
      recentList.add(m.toString());
    }
    await Shared(SharedKeys.recentTrackpoints).save(recentList.join('\n'));
  }
}
