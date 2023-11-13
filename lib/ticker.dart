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

enum TickerTypes {
  hud,
  background;
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

  int _ticks = 0;
  int get ticks => _ticks;
  bool isRunning = true;
  Future<Duration> Function() getDuration;
  void Function() action;

  Ticker._ticker({required this.getDuration, required this.action}) {
    getDuration.call().then(
      (duration) {
        Future.microtask(
          () async {
            while (isRunning) {
              try {
                action.call();
                EventManager.fire<EventOnAppTick>(EventOnAppTick());
                _ticks++;
              } catch (e, stk) {
                logger.error(
                    'appTick ${DateTime.now().toIso8601String()} failed: $e',
                    stk);
              }
              await Future.delayed(duration);
            }
          },
        );
      },
    ).onError((e, stk) {
      logger.fatal('', stk);
    });
  }
}
