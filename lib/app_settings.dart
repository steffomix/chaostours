import 'package:chaostours/shared.dart';
import 'package:chaostours/globals.dart';
import 'package:chaostours/logger.dart';

/// names for SharedKeys.appSettings key:value pairs
enum AppSettings {
  /// comma separated list of user ids
  preselectedUsers,

  /// boolean
  statusStandingRequireAlias,

  /// in seconds
  trackPointInterval,

  /// in seconds
  addressLookupInterval,

  /// enum of OsmLookup{ never, onStatus, always }
  osmLookupCondition,

  /// Gps cache Time in seconds
  cacheGpsTime,

  /// in meters
  distanceTreshold,

  /// in seconds
  timeRangeTreshold,

  /// in seconds
  waitTimeAfterStatusChanged,

  /// general Tick in seconds
  appTickDuration;

  const AppSettings();

  static bool _settingsLoaded = false;

  static final Logger logger = Logger.logger<AppSettings>();

  /// load app defaults from globals, to be overwritten by loadFromShared
  static Map<AppSettings, String> settings = {
    AppSettings.preselectedUsers:
        Globals.preselectedUsers.join(','), // List<int>
    AppSettings.statusStandingRequireAlias:
        Globals.statusStandingRequireAlias ? '1' : '0', // bool
    AppSettings.trackPointInterval:
        Globals.trackPointInterval.inSeconds.toString(), // int
    AppSettings.addressLookupInterval:
        Globals.addressLookupInterval.inSeconds.toString(), // int
    AppSettings.osmLookupCondition:
        Globals.osmLookupCondition.name, // String enum name
    AppSettings.cacheGpsTime: Globals.cacheGpsTime.inSeconds.toString(), // int
    AppSettings.distanceTreshold: Globals.distanceTreshold.toString(), // int
    AppSettings.timeRangeTreshold:
        Globals.timeRangeTreshold.inSeconds.toString(), // int
    AppSettings.waitTimeAfterStatusChanged:
        Globals.waitTimeAfterStatusChanged.inSeconds.toString(), // int
    AppSettings.appTickDuration:
        Globals.appTickDuration.inSeconds.toString() // bool 1|0
  };

  /// update called in WidgetAppSettings
  static void updateGlobals() {
    if (!_settingsLoaded) {
      loadFromShared().then((_) => updateGlobals());
      return;
    }
    try {
      if (settings[AppSettings.preselectedUsers]?.isNotEmpty ?? false) {
        Globals.preselectedUsers =
            (settings[AppSettings.preselectedUsers] ?? '')
                .split(',')
                .map((e) => int.parse(e))
                .toList();
      } else {
        Globals.preselectedUsers = [];
      }
    } catch (e, stk) {
      logger.error(e.toString(), stk);
    }

    try {
      String? sr = settings[AppSettings.statusStandingRequireAlias];

      Globals.statusStandingRequireAlias =
          (settings[AppSettings.statusStandingRequireAlias] ?? '0') == '1'
              ? true
              : false;
    } catch (e, stk) {
      logger.error(e.toString(), stk);
    }
    try {
      ///
      Globals.trackPointInterval = Duration(
          seconds: int.parse(settings[AppSettings.trackPointInterval] ?? '30'));
    } catch (e, stk) {
      logger.error(e.toString(), stk);
    }

    /// addressLookupInterval
    int iv = 0;
    try {
      // 0 = disabled but 10 = min value
      iv = int.parse(settings[AppSettings.addressLookupInterval] ?? '0');
      if (iv > 0 && iv < 10) {
        iv = 10;
      }
      Globals.addressLookupInterval = Duration(seconds: iv);
    } catch (e) {
      logger.warn(
          'addressLookupInterval has invalid value: ${settings[AppSettings.addressLookupInterval]}');
    }

    try {
      ///
      Globals.osmLookupCondition = OsmLookup.values.byName(
          settings[AppSettings.osmLookupCondition] ?? OsmLookup.never.name);
    } catch (e, stk) {
      logger.error(e.toString(), stk);
    }

    try {
      ///
      Globals.cacheGpsTime = Duration(
          seconds: int.parse(settings[AppSettings.cacheGpsTime] ?? '10'));
    } catch (e, stk) {
      logger.error(e.toString(), stk);
    }

    try {
      ///
      Globals.distanceTreshold =
          int.parse(settings[AppSettings.distanceTreshold] ?? '100');
    } catch (e, stk) {
      logger.error(e.toString(), stk);
    }

    try {
      ///
      Globals.timeRangeTreshold = Duration(
          seconds: int.parse(settings[AppSettings.timeRangeTreshold] ?? '300'));
    } catch (e, stk) {
      logger.error(e.toString(), stk);
    }

    try {
      ///
      Globals.waitTimeAfterStatusChanged = Duration(
          seconds: int.parse(
              settings[AppSettings.waitTimeAfterStatusChanged] ?? '300'));

      ///
      Globals.appTickDuration = Duration(
          seconds: int.parse(settings[AppSettings.appTickDuration] ?? '1'));
    } catch (e, stk) {
      logger.error(e.toString(), stk);
    }
  }

  static Future<void> saveToShared() async {
    List<String> values = [];
    settings.forEach((key, value) {
      logger.log('save settings $key : $value');
      values.add('${key.name}:$value');
    });

    await Shared(SharedKeys.appSettings).saveList(values);
  }

  static Future<void> loadFromShared() async {
    /// set it at the beginning to prevent a loop if something fails
    _settingsLoaded = true;

    /// load shared data
    List<String> values = await Shared(SharedKeys.appSettings).loadList() ?? [];
    if (values.isEmpty) {
      /// app is running first time
      /// store hard coded default values and reload again
      await saveToShared();
      values = await Shared(SharedKeys.appSettings).loadList() ?? [];
    }
    for (var item in values) {
      if (item.isEmpty) {
        continue;
      }
      try {
        List<String> parts = item.split(':');
        String value = parts[1];
        try {
          AppSettings key = AppSettings.values.byName(parts[0]);
          switch (key) {
            /// defaults to Globals.preselectedUsers
            case AppSettings.preselectedUsers:
              Globals.preselectedUsers =
                  value.split(',').map((e) => int.parse(e)).toList();
              break;

            /// defaults to false
            case AppSettings.statusStandingRequireAlias:
              Globals.statusStandingRequireAlias = value == '1' ? true : false;
              break;

            /// defaults to Globals.trackPointInterval
            case AppSettings.trackPointInterval:
              Globals.trackPointInterval = Duration(seconds: int.parse(value));
              break;

            /// defaults to Globals.addressLookupInterval
            case AppSettings.addressLookupInterval:
              Globals.addressLookupInterval =
                  Duration(seconds: int.parse(value));
              break;

            /// defaults to Globals.osmLookupCondition
            case AppSettings.osmLookupCondition:
              Globals.osmLookupCondition = OsmLookup.values.byName(value);
              break;
            // defaults to lobals.cacheGpsTime
            case AppSettings.cacheGpsTime:
              Globals.cacheGpsTime = Duration(seconds: int.parse(value));
              break;

            /// defaults to Globals.distanceTreshold
            case AppSettings.distanceTreshold:
              Globals.distanceTreshold = int.parse(value);
              break;

            /// defaults to Globals.timeRangeTreshold
            case AppSettings.timeRangeTreshold:
              Globals.timeRangeTreshold = Duration(seconds: int.parse(value));
              break;

            /// defaults to Globals.waitTimeAfterStatusChanged
            case AppSettings.waitTimeAfterStatusChanged:
              Globals.waitTimeAfterStatusChanged =
                  Duration(seconds: int.parse(value));
              break;

            /// defaults to Globals.appTickDuration
            case AppSettings.appTickDuration:
              Globals.appTickDuration = Duration(seconds: int.parse(value));
              break;
            default:
            // do nothing
          }
        } catch (e, stk) {
          logger.error(e.toString(), stk);
          continue;
        }
        logger.log('load setting ${parts[0]} : $value');
      } catch (e, stk) {
        logger.error('Shared loaded AppSetting "$item" invalid', stk);
      }
    }
  }
}
