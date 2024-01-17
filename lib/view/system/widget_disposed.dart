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
import 'package:chaostours/event_manager.dart';

class EventOnWidgetDisposed {}

class WidgetDisposed extends StatefulWidget {
  const WidgetDisposed({super.key});

  @override
  State<WidgetDisposed> createState() => _WidgetDisposed();
}

class _WidgetDisposed extends State<WidgetDisposed> {
  @override
  void dispose() {
    EventManager.fire<EventOnWidgetDisposed>(EventOnWidgetDisposed());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
