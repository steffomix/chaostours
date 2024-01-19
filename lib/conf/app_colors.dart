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

import 'package:flutter/material.dart';
import 'package:chaostours/model/model_alias.dart';

///
enum AppColors {
  /// theme colors
  green(Color(0xFF4b830d)),

  /// icons
  black(Colors.black87),

  /// warning Background
  danger(Colors.red),
  warning(Colors.amber),

  dialogBarrirer(Color.fromARGB(164, 0, 0, 0)),

  /// transparent background
  iconDisabled(Colors.white54),

  /// alias colors
  aliasRestricted(Colors.red),
  aliasPrivate(Colors.blue),
  aliasPublic(Colors.green),

  /// tracking dot colors
  rawGpsTrackingDot(Color.fromARGB(255, 111, 111, 111)),
  smoothedGpsTrackingDot(Colors.black),
  calcGpsTrackingDot(Color.fromARGB(255, 34, 156, 255)),
  lastTrackingStatusWithAliasDot(Colors.red),
  currentGpsDot(Color.fromARGB(255, 247, 2, 255));

  static Color aliasStatusColor(AliasPrivacy status) {
    switch (status) {
      case AliasPrivacy.public:
        return aliasPublic.color;
      case AliasPrivacy.privat:
        return aliasPrivate.color;
      default:
        return aliasRestricted.color;
    }
  }

  final Color color;
  const AppColors(this.color);
}
