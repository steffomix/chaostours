import 'package:chaostours/conf/app_user_settings.dart';
import 'package:chaostours/event_manager.dart';
import 'package:flutter/material.dart';

import 'package:chaostours/ticker.dart';
import 'package:chaostours/database/cache.dart';

class RuntimeData {
  static WidgetsBinding? widgetsFlutterBinding;
  static final GlobalKey<NavigatorState> globalKey =
      GlobalKey<NavigatorState>(debugLabel: 'Global Key');
  static BuildContext? get context => globalKey.currentContext;

  RuntimeData._();
  static RuntimeData? _instance;
  factory RuntimeData() => _instance ??= RuntimeData._();

  Ticker foregroudTrackingTicker = Ticker(
    type: TickerTypes.foregroundTrackingTicker,
    getDuration: () async {
      var cache = Cache.appSettingForegroundUpdateInterval;
      return await cache
          .loadCache<Duration>(AppUserSetting(cache).defaultValue as Duration);
    },
    action: () {
      EventManager.fire<EventOnForegroundTracking>(EventOnForegroundTracking());
    },
  );

  Ticker backgroundLookupTicker = Ticker(
    type: TickerTypes.backgroundLookupTicker,
    getDuration: () async {
      var cache = Cache.appSettingBackgroundTrackingInterval;
      return await cache
          .loadCache<Duration>(AppUserSetting(cache).defaultValue as Duration);
    },
    action: () {
      EventManager.fire<EventOnBackgroundUpdate>(EventOnBackgroundUpdate());
    },
  );
}
