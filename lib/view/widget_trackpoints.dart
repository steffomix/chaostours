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

class WidgetTrackPoints extends StatefulWidget {
  const WidgetTrackPoints({super.key});

  @override
  State<WidgetTrackPoints> createState() => _WidgetTrackPointsState();
}

class _WidgetTrackPointsState extends State<WidgetTrackPoints> {
  TextEditingController tpSearch = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AppWidgets.scaffold(context,
        appBar: AppBar(title: const Text('Haltepunkte')),
        body: AppWidgets.renderTrackPointSearchList(
            context: context,
            textController: tpSearch,
            onUpdate: () {
              setState(() {});
            }));
  }
}
