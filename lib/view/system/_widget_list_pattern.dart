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

///
// import 'package:chaostours/logger.dart';
import 'package:chaostours/view/system/app_widgets.dart';
import 'package:chaostours/view/system/app_base_widget.dart';

class WidgetPattern extends BaseWidget {
  const WidgetPattern({super.key});
  @override
  State<WidgetPattern> createState() => _WidgetPattern();
}

class _WidgetPattern extends BaseWidgetState<WidgetPattern>
    implements BaseWidgetInterface {
  //static final Logger logger = Logger.logger<WidgetPattern>();

  final List<Widget> loadedItems = [];

  @override
  int loaderLimit() => 20;

  @override
  Future<void> initialize(BuildContext context, Object? args) async {}

  @override
  Future<void> resetLoader() async {
    await super.resetLoader();
    loadedItems.clear();
  }

  @override
  Future<int> loadItems({required int offset, int limit = 5}) async {
    loadedItems.add(Text('${loadedItems.length + 1}x not implemented'));
    return 1;
  }

  @override
  List<Widget> renderHeader(BoxConstraints constraints) {
    return <Widget>[const Text('not implemented')];
  }

  @override
  List<Widget> renderBody(BoxConstraints constraints) {
    return <Widget>[const Text('not implemented')];
  }

  @override
  Scaffold renderScaffold(Widget body) {
    return AppWidgets.scaffold(context, body: body);
  }
}
