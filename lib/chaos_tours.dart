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

import 'package:chaostours/database/cache.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:chaostours/view/system/app_widgets.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class ChaosTours extends StatelessWidget {
  static start() async {
    WidgetsFlutterBinding.ensureInitialized();
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    GoogleFonts.config.allowRuntimeFetching = false;

    try {
      await Cache.appSettingsColorScheme.load<FlexScheme>(FlexScheme.gold);
    } catch (e) {
      //
    }

    runApp(const ChaosTours());
  }

  const ChaosTours({super.key});

  @override
  Widget build(BuildContext context) {
    return AppWidgets.materialApp(context);
  }
}
