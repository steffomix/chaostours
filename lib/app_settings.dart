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
      if (settings['preselectedUsers']?.isNotEmpty ?? false) {
        Globals.preselectedUsers = (settings['preselectedUsers'] ?? '')
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
      Globals.statusStandingRequireAlias =
          (settings['statusStandingRequireAlias'] ?? '0') == '1' ? true : false;
    } catch (e, stk) {
      logger.error(e.toString(), stk);
    }
    try {
      ///
      Globals.trackPointInterval =
          Duration(seconds: int.parse(settings['trackPointInterval'] ?? '30'));
    } catch (e, stk) {
      logger.error(e.toString(), stk);
    }

    /// addressLookupInterval
    int iv = 0;
    try {
      // 0 = disabled but 10 = min value
      iv = int.parse(settings['addressLookupInterval'] ?? '0');
      if (iv > 0 && iv < 10) {
        iv = 10;
      }
    } catch (e) {
      logger.warn(
          'addressLookupInterval has invalid value: ${settings['addressLookupInterval']}');
    }
    Globals.addressLookupInterval = Duration(seconds: iv);

    try {
      ///
      Globals.osmLookupCondition = OsmLookup.values
          .byName(settings['osmLookupCondition'] ?? OsmLookup.never.name);
    } catch (e, stk) {
      logger.error(e.toString(), stk);
    }

    try {
      ///
      Globals.cacheGpsTime =
          Duration(seconds: int.parse(settings['cacheGpsTime'] ?? '10'));
    } catch (e, stk) {
      logger.error(e.toString(), stk);
    }

    ///
    Globals.distanceTreshold = int.parse(settings['distanceTreshold'] ?? '100');

    try {
      ///
      Globals.timeRangeTreshold =
          Duration(seconds: int.parse(settings['timeRangeTreshold'] ?? '300'));
    } catch (e, stk) {
      logger.error(e.toString(), stk);
    }

    try {
      ///
      Globals.waitTimeAfterStatusChanged = Duration(
          seconds: int.parse(settings['waitTimeAfterStatusChanged'] ?? '300'));

      ///
      Globals.appTickDuration =
          Duration(seconds: int.parse(settings['appTickDuration'] ?? '1'));
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
        String key = parts[0];
        String value = parts[1];
        switch (key) {
          /// defaults to Globals.preselectedUsers
          case 'preselectedUsers':
            Globals.preselectedUsers =
                value.split(',').map((e) => int.parse(e)).toList();
            break;

          /// defaults to false
          case 'statusStandingRequireAlias':
            Globals.statusStandingRequireAlias = value == '1' ? true : false;
            break;

          /// defaults to Globals.trackPointInterval
          case 'trackPointInterval':
            Globals.trackPointInterval = Duration(seconds: int.parse(value));
            break;

          /// defaults to Globals.addressLookupInterval
          case 'addressLookupInterval':
            Globals.addressLookupInterval = Duration(seconds: int.parse(value));
            break;

          /// defaults to Globals.osmLookupCondition
          case 'osmLookupCondition':
            Globals.osmLookupCondition = OsmLookup.values.byName(value);
            break;
          // defaults to lobals.cacheGpsTime
          case 'cacheGpsTime':
            Globals.cacheGpsTime = Duration(seconds: int.parse(value));
            break;

          /// defaults to Globals.distanceTreshold
          case 'distanceTreshold':
            Globals.distanceTreshold = int.parse(value);
            break;

          /// defaults to Globals.timeRangeTreshold
          case 'timeRangeTreshold':
            Globals.timeRangeTreshold = Duration(seconds: int.parse(value));
            break;

          /// defaults to Globals.waitTimeAfterStatusChanged
          case 'waitTimeAfterStatusChanged':
            Globals.waitTimeAfterStatusChanged =
                Duration(seconds: int.parse(value));
            break;

          /// defaults to Globals.appTickDuration
          case 'appTickDuration':
            Globals.appTickDuration = Duration(seconds: int.parse(value));
            break;
          default:
          // do nothing
        }
        logger.log('load setting $key : $value');
      } catch (e, stk) {
        logger.error('Shared loaded AppSetting "$item" invalid', stk);
      }
    }
  }
}
