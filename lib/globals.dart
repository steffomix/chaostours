import 'package:path/path.dart';

///
import 'package:chaostours/logger.dart';

enum OsmLookup { never, onStatus, always }

enum Storages {
  /// app installation directory
  /// unreachable
  appInternal,

  /// app data directory of internal storage
  /// .android/data/com.stefanbrinkmann.chaostours/files/chaostours/1.0
  /// on new devices only reachable with Computer and Datacable
  appLocalStorageData,

  /// app data directory of internal storage
  /// localStorage/Documents
  /// on new devices only reachable with Computer and Datacable
  appLocalStorageDocuments,

  /// Documents on sdCard
  /// <sdCard>/Documents/chaostours/1.0
  appSdCardDocuments;
}

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

  /// storage
  static Storages? storageKey;
  static String? storagePath;

  static String version = '1.0';
  static const bool debugMode = true;
  static double distanceTreshold = 100; //meters
  static OsmLookup osmLookup = OsmLookup.always;

  static Duration get appTickDuration => const Duration(seconds: 1);

  static List<String> weekDays = ['', 'Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

  static final List<int> preselectedUsers = [1, 2];

  /// save battery with cache time
  static Duration get cacheGpsTime {
    return const Duration(seconds: 20);
  }

  // durations and distances
  // skip status check for given time to prevent mass actions
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
