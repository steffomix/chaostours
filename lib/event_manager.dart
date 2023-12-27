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

import 'package:chaostours/channel/tracking.dart';

class EventOnTrackingStatusChanged extends EventOn {
  final TrackingStatus oldStatus;
  final TrackingStatus status;

  EventOnTrackingStatusChanged({required this.status, required this.oldStatus});
}

class EventOnBackgroundUpdate extends EventOn {}

class EventOnRender extends EventOn {}

class EventOn {
  static int _nextId = 1;
  int id = (_nextId++);
  DateTime t = DateTime.now();
}

class EventManager {
  static final List<Set<dynamic>> _register = [];

  static bool listen<T>(Function(T) fn) {
    var reg = _register.whereType<Set<Function(T)>>();
    if (reg.isEmpty) {
      Set<Function(T)> s = {fn};
      _register.add(s);
      return true;
    } else {
      return reg.first.add(fn);
    }
  }

  static fire<T>(T event) async {
    for (var fn in _get<T>()) {
      Future.microtask(() => fn(event));
    }
  }

  static void remove<T>(Function(T) fn) => _register
      .whereType<Set<Function(T)>>()
      .firstOrNull
      ?.removeWhere((el) => el == fn);

  static List<Function(T)> _get<T>() => List.unmodifiable(
      _register.whereType<Set<Function(T)>>().firstOrNull?.toList() ?? []);
}
