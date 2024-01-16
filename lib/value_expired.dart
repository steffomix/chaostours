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

enum ExpiredValue {
  never(Duration.zero),
  immediately(Duration.zero),
  oneSecond(Duration(seconds: 1)),
  tenSeconds(Duration(seconds: 10)),
  oneMinute(Duration(minutes: 1));

  final Duration duration;
  const ExpiredValue(this.duration);
}

class ValueExpired {
  final DateTime now = DateTime.now();
  final ExpiredValue expireAfter;
  dynamic value;
  bool _isExpired = false;

  void expire() {
    _isExpired = true;
  }

  ValueExpired({required this.value, required this.expireAfter});

  bool get isExpired {
    switch (expireAfter) {
      case ExpiredValue.never:
        return false;
      case ExpiredValue.immediately:
        return true;
      default:
        return _isExpired ||
            DateTime.now().isAfter(now.add(expireAfter.duration));
    }
  }
}
