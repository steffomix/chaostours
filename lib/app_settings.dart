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

  static final Logger logger = Logger.logger<AppSettings>();

  /// only useful in WidgetAppSettings
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
  static void update() {
    try {
      Globals.preselectedUsers = (settings['preselectedUsers'] ?? '')
          .split(',')
          .map((e) => int.parse(e))
          .toList();

      Globals.statusStandingRequireAlias =
          (settings['statusStandingRequireAlias'] ?? '1') == '1' ? true : false;

      ///
      Globals.trackPointInterval =
          Duration(seconds: int.parse(settings['trackPointInterval'] ?? '30'));

      ///
      Globals.addressLookupInterval = Duration(
          seconds: int.parse(settings['addressLookupInterval'] ?? '0'));

      ///
      Globals.osmLookupCondition = OsmLookup.values
          .byName(settings['osmLookupCondition'] ?? OsmLookup.never.name);

      ///
      Globals.cacheGpsTime =
          Duration(seconds: int.parse(settings['cacheGpsTime'] ?? '10'));

      ///
      Globals.distanceTreshold =
          int.parse(settings['distanceTreshold'] ?? '100');

      ///
      Globals.timeRangeTreshold =
          Duration(seconds: int.parse(settings['timeRangeTreshold'] ?? '300'));

      ///
      Globals.waitTimeAfterStatusChanged = Duration(
          seconds: int.parse(settings['waitTimeAfterStatusChanged'] ?? '300'));

      ///
      Globals.appTickDuration =
          Duration(seconds: int.parse(settings['appTickDuration'] ?? '1'));
    } catch (e) {
      ///
    }
  }

  static Future<void> save() async {
    List<String> values = [];
    settings.forEach((key, value) {
      logger.log('save settings $key : $value');
      values.add('${key.name}:$value');
    });

    await Shared(SharedKeys.appSettings).saveList(values);
  }

  static Future<void> load() async {
    List<String> values = await Shared(SharedKeys.appSettings).loadList() ?? [];
    if (values.isEmpty) {
      /// app is running first time
      /// store hard coded default values and reload again
      await save();
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
          case 'preselectedUsers':
            Globals.preselectedUsers =
                value.split(',').map((e) => int.parse(e)).toList();
            break;
          case 'statusStandingRequireAlias':
            Globals.statusStandingRequireAlias = value == '1' ? true : false;
            break;
          case 'trackPointInterval':
            Globals.trackPointInterval = Duration(seconds: int.parse(value));
            break;
          case 'addressLookupInterval':
            Globals.addressLookupInterval = Duration(seconds: int.parse(value));
            break;
          case 'osmLookupCondition':
            Globals.osmLookupCondition = OsmLookup.values.byName(value);
            break;
          case 'cacheGpsTime':
            Globals.cacheGpsTime = Duration(seconds: int.parse(value));
            break;
          case 'distanceTreshold':
            Globals.distanceTreshold = int.parse(value);
            break;
          case 'timeRangeTreshold':
            Globals.timeRangeTreshold = Duration(seconds: int.parse(value));
            break;
          case 'waitTimeAfterStatusChanged':
            Globals.waitTimeAfterStatusChanged =
                Duration(seconds: int.parse(value));
            break;
          case 'appTickDuration':
            Globals.appTickDuration = Duration(seconds: int.parse(value));
            break;
          default:
          // do nothing
        }
        logger.log('load setting $key : $value');
      } catch (e, stk) {
        logger.error(e.toString(), stk);
      }
    }
  }
}
