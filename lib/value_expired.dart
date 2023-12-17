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

class ValueExpired {
  dynamic value;

  late DateTime _expiredAt;
  bool get isExpired => DateTime.now().isAfter(_expiredAt);

  void expire() {
    _expiredAt = DateTime.now().subtract(const Duration(seconds: 1));
  }

  ValueExpired({required this.value, required Duration duration}) {
    _expiredAt = DateTime.now().add(duration);
  }
}
