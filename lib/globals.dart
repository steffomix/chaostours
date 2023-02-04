import 'package:chaostours/logger.dart';

enum OsmLookup { never, onStatus, always }

class Globals {
  static Logger logger = Logger.logger<Globals>();

  ///
  /// App from widget_main
  ///
  /*
  double width = MediaQuery.of(context).size.width;
double height = MediaQuery.of(context).size.height;
To get height just of SafeArea (for iOS 11 and above):

var padding = MediaQuery.of(context).padding;
double newheight = height - padding.top - padding.bottom;
*/

  static String version = '';
  static const bool debugMode = true;
  static double distanceTreshold = 100; //meters
  static OsmLookup osmLookup = OsmLookup.always;

  static Duration get appTickDuration => Duration(seconds: 1);

  // durations and distances
  // skip status check for given time to prevent ugly things
  static Duration get waitTimeAfterStatusChanged {
    return debugMode
        ? const Duration(seconds: 10)
        : const Duration(seconds: 60);
  }

  /// stop time needed to trigger stop.
  /// Shoud be at least 3 times more than Globals.tickTrackPointDuration
  static Duration get stopTimeTreshold {
    return debugMode
        ? const Duration(seconds: 30)
        : const Duration(seconds: 180);
  }

  /// check status interval.
  /// Should be at least 3 seconds due to GPS lookup needs at least 2 seconds
  static Duration get tickTrackPointDuration {
    return debugMode
        ? const Duration(seconds: 10)
        : const Duration(seconds: 60);
  }

  /// consumes mobile data!
  static Duration get addressLookupDuration {
    return debugMode
        ? const Duration(seconds: 10)
        : const Duration(seconds: 60);
  }
}
