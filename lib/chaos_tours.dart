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
import 'package:chaostours/view/app_widgets.dart';
import 'package:google_fonts/google_fonts.dart';
//import 'package:chaostours/runtime_data.dart';

class ChaosTours extends StatelessWidget {
  static start() {
    WidgetsFlutterBinding.ensureInitialized();

    GoogleFonts.config.allowRuntimeFetching = false;
    runApp(const ChaosTours());
  }

  const ChaosTours({super.key});

  @override
  Widget build(BuildContext context) {
    return AppWidgets.materialApp(context);
  }
}