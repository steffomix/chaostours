import 'package:chaostours/logger.dart';

enum OsmLookup { never, onStatus, always }

class Globals {
  static Logger logger = Logger.logger<Globals>();

  ///
  /// App from widget_main
  ///

  static String version = '';
  static const bool debugMode = false;
  static double distanceTreshold = 100; //meters
  static OsmLookup osmLookup = OsmLookup.always;

  // durations and distances
  // skip status check for given time to prevent ugly things
  static Duration get waitTimeAfterStatusChanged {
    return debugMode ? const Duration(seconds: 1) : const Duration(seconds: 20);
  }

  // stop time needed to trigger stop
  static Duration get stopTimeTreshold {
    return debugMode ? const Duration(seconds: 10) : const Duration(minutes: 1);
  }

  // check status interval
  static Duration get trackPointTickTime {
    return debugMode ? const Duration(seconds: 2) : const Duration(seconds: 5);
  }
}
