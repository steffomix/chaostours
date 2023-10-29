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

import 'package:chaostours/view/app_base_widget.dart';
import 'package:flutter/material.dart';
import 'package:device_calendar/device_calendar.dart';

///
import 'package:chaostours/view/app_widgets.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/model/model_alias_group.dart';
import 'package:chaostours/conf/app_routes.dart';
import 'package:chaostours/calendar.dart';

class WidgetUserGroupList extends BaseWidget {
  const WidgetUserGroupList({super.key});

  @override
  State<WidgetUserGroupList> createState() => _WidgetUserGroupList();
}

class _WidgetUserGroupList extends BaseWidgetState<WidgetUserGroupList> {}
