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

abstract class SharedTrackpointAsset {
  static final Logger logger = Logger.logger<SharedTrackpointAsset>();
  static const separator = r';';

  @override
  String toString() {
    return '$id$separator$notes';
  }

  final int id;
  final String notes;

  SharedTrackpointAsset({required this.id, required this.notes});
}
