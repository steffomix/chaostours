import 'package:chaostours/conf/app_settings.dart';
import 'package:chaostours/event_manager.dart';
import 'package:flutter/material.dart';

import 'package:chaostours/ticker.dart';
import 'package:chaostours/cache.dart';

class RuntimeData {
  static WidgetsBinding? widgetsFlutterBinding;
  static final GlobalKey<NavigatorState> globalKey =
      GlobalKey<NavigatorState>(debugLabel: 'Global Key');
  static BuildContext? get context => globalKey.currentContext;

  static Ticker hudTicker = Ticker(
    type: TickerTypes.hud,
    getDuration: () async {
      var cache = Cache.appSettingForegroundUpdateInterval;
      return await cache
          .load<Duration>(AppUserSettings(cache).defaultValue as Duration);
    },
    action: () {
      EventManager.fire<EventOnAppTick>(EventOnAppTick());
    },
  );

  static Ticker backgroundTicker = Ticker(
    type: TickerTypes.background,
    getDuration: () async {
      var cache = Cache.appSettingBackgroundTrackingInterval;
      return await cache
          .load<Duration>(AppUserSettings(cache).defaultValue as Duration);
    },
    action: () {
      EventManager.fire<EventOnBackgroundUpdate>(EventOnBackgroundUpdate());
    },
  );
}
