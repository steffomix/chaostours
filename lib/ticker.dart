/*
Copyright 2023 Stefan Brinkmann <st.brinkmann@gmail.com>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

import 'package:chaostours/event_manager.dart';
import 'package:chaostours/logger.dart';

class Ticker {
  static final Logger logger = Logger.logger<Ticker>();

  static int _appTick = 0;
  static get appTick => _appTick;

  static bool _appTickIsRunning = false;
  static bool get appTickIsRunning => _appTickIsRunning;

  static Duration appTickDuration = const Duration(seconds: 1);

  static Future<void> startAppTick() async {
    if (_appTickIsRunning) {
      return;
    }
    _appTickIsRunning = true;
    while (true) {
      try {
        EventManager.fire<EventOnAppTick>(EventOnAppTick());
        _appTick++;
      } catch (e, stk) {
        logger.error(
            'appTick ${DateTime.now().toIso8601String()} failed: $e', stk);
      }
      await Future.delayed(appTickDuration);
    }
  }
}
