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

import 'package:flutter/widgets.dart';

class Screen {
  final BuildContext context;

  /// init with some secure values
  late double width;
  late double height;
  late EdgeInsets padding;
  late double newHeight;

  Screen(this.context) {
    width = MediaQuery.of(context).size.width;
    height = MediaQuery.of(context).size.height;
    // To get height just of SafeArea (for iOS 11 and above):
    padding = MediaQuery.of(context).padding;
    newHeight = height - padding.top - padding.bottom;
  }

  double percentWidth(double percent) {
    return width / 100 * percent;
  }

  double percentHeight(double percent) {
    return height / 100 * percent;
  }
}
