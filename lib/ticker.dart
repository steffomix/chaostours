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

import 'package:chaostours/logger.dart';

enum TickerTypes {
  foregroundTrackingTicker,
  backgroundLookupTicker;
}

class Ticker {
  static final Logger logger = Logger.logger<Ticker>();
  static final Map<TickerTypes, Ticker> _runningTickers = {};

  factory Ticker(
      {required TickerTypes type,
      required Future<Duration> Function() getDuration,
      required void Function() action}) {
    return _runningTickers[type] ??=
        Ticker._ticker(getDuration: getDuration, action: action);
  }

  Ticker? getTicker(TickerTypes type) {
    return _runningTickers[type];
  }

  void dispose() {
    _isRunning = false;
  }

  int _ticks = 0;
  int get ticks => _ticks;
  bool _isRunning = true;
  Future<Duration> Function() getDuration;
  void Function() action;

  Ticker._ticker({required this.getDuration, required this.action}) {
    Future.microtask(
      () async {
        while (_isRunning) {
          try {
            action.call();
            _ticks++;
          } catch (e, stk) {
            logger.error(
                'appTick ${DateTime.now().toIso8601String()} failed: $e', stk);
          }
          var duration = await getDuration();
          if (duration.inSeconds < 1) {
            await Future.delayed(const Duration(seconds: 1));
          }
          await Future.delayed(duration);
        }
      },
    );
  }
}
