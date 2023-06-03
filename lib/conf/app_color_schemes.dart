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

/// Source of schemes: https://rydmike.com/flexcolorscheme
enum AppColorShemes {
  mangoMojito(
      light: ColorScheme(
        brightness: Brightness.light,
        primary: Color(0xffc78d20),
        onPrimary: Color(0xffffffff),
        primaryContainer: Color(0xffdeb059),
        onPrimaryContainer: Color(0xff120f08),
        secondary: Color(0xff616247),
        onSecondary: Color(0xffffffff),
        secondaryContainer: Color(0xffbcbca8),
        onSecondaryContainer: Color(0xff10100e),
        tertiary: Color(0xff8d9440),
        onTertiary: Color(0xffffffff),
        tertiaryContainer: Color(0xffbfc39b),
        onTertiaryContainer: Color(0xff10100d),
        error: Color(0xffb00020),
        onError: Color(0xffffffff),
        errorContainer: Color(0xfffcd8df),
        onErrorContainer: Color(0xff141213),
        background: Color(0xfffdfaf7),
        onBackground: Color(0xff090909),
        surface: Color(0xfffdfaf7),
        onSurface: Color(0xff090909),
        surfaceVariant: Color(0xfffbf6ef),
        onSurfaceVariant: Color(0xff131312),
        outline: Color(0xff565656),
        outlineVariant: Color(0xffa2a2a2),
        shadow: Color(0xff000000),
        scrim: Color(0xff000000),
        inverseSurface: Color(0xff171511),
        onInverseSurface: Color(0xfff5f5f5),
        inversePrimary: Color(0xfffff8b9),
        surfaceTint: Color(0xffc78d20),
      ),
      dark: ColorScheme(
        brightness: Brightness.dark,
        primary: Color(0xffdeb059),
        onPrimary: Color(0xff14110a),
        primaryContainer: Color(0xffc78d20),
        onPrimaryContainer: Color(0xfffff5e4),
        secondary: Color(0xff81816c),
        onSecondary: Color(0xfff9f9f7),
        secondaryContainer: Color(0xff5a5a35),
        onSecondaryContainer: Color(0xffedede8),
        tertiary: Color(0xffafb479),
        onTertiary: Color(0xff11120d),
        tertiaryContainer: Color(0xff82883d),
        onTertiaryContainer: Color(0xfff4f5e9),
        error: Color(0xffcf6679),
        onError: Color(0xff140c0d),
        errorContainer: Color(0xffb1384e),
        onErrorContainer: Color(0xfffbe8ec),
        background: Color(0xff1d1a15),
        onBackground: Color(0xffededec),
        surface: Color(0xff1d1a15),
        onSurface: Color(0xffededec),
        surfaceVariant: Color(0xff292319),
        onSurfaceVariant: Color(0xffdddcda),
        outline: Color(0xffa3a39d),
        outlineVariant: Color(0xff565651),
        shadow: Color(0xff000000),
        scrim: Color(0xff000000),
        inverseSurface: Color(0xfffdfaf5),
        onInverseSurface: Color(0xff131313),
        inversePrimary: Color(0xff6f5b35),
        surfaceTint: Color(0xffdeb059),
      ));

  final ColorScheme light;
  final ColorScheme dark;

  const AppColorShemes({required this.light, required this.dark});
}