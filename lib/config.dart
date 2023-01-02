class AppConfig {
  static const bool debugMode = false;

  static String version = '';

  static double distanceTreshold = 100; //meters

  static bool alwaysLookupAddress = true;

  // durations and distances
  // skip status check for given time to prevent ugly things
  static Duration get waitTimeAfterStatusChanged {
    return debugMode ? const Duration(seconds: 1) : const Duration(minutes: 1);
  }

  // stop time needed to trigger stop
  static Duration get stopTimeTreshold {
    return debugMode ? const Duration(seconds: 10) : const Duration(minutes: 3);
  }

  // check status interval
  static Duration get trackPointTickTime {
    return debugMode ? const Duration(seconds: 2) : const Duration(seconds: 20);
  }
}
