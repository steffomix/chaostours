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
import 'package:chaostours/event_manager.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/view/app_widgets.dart';
import 'package:chaostours/globals.dart';

class WidgetLoggerPage extends StatefulWidget {
  const WidgetLoggerPage({super.key});

  @override
  State<WidgetLoggerPage> createState() => _WidgetLoggerPage();
}

class _WidgetLoggerPage extends State<WidgetLoggerPage> {
  static List<Widget> logs = [];
  static int counter = 0;

  @override
  void dispose() {
    EventManager.remove<EventOnAppTick>(onTick);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    EventManager.listen<EventOnAppTick>(onTick);
  }

  Future<void> onTick(EventOnAppTick event) async {
    counter++;
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      logs.add(const Text('No Logs yet...'));
    }
    var loggerLogs = Logger.loggerLogs;
    ListView renderedLogs = ListView.builder(
      itemCount: loggerLogs.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Text('Ticks: ${Globals.appTicks}');
        }
        var e = loggerLogs[index - 1];
        return renderLog(e);
      },
    );
    return AppWidgets.scaffold(context,
        body: renderedLogs, appBar: AppBar(title: const Text('Logger')));
  }

  ///
  ///
  ///
  ///
  ///

  static String get time {
    DateTime t = DateTime.now();
    var m = t.minute;
    var s = t.second;
    var ms = t.millisecond;
    return '$m:$s.$ms';
  }

  static Widget renderLog(LoggerLog log) {
    var t = log.time;
    String time = '${t.hour}:${t.minute}:${t.second}::${t.millisecond}';
    String msg =
        '${log.prefix}$time ::${log.level.name} <${log.name}>:: ${log.msg}';

    switch (log.level) {
      case LogLevel.verbose:
        return Container(
            margin: const EdgeInsets.only(top: 6),
            color: Colors.white,
            child: Text(msg, style: const TextStyle(color: Colors.black45)));

      case LogLevel.log:
        return Container(
            margin: const EdgeInsets.only(top: 6),
            color: Colors.white,
            child: Text(msg, style: const TextStyle(color: Colors.black)));

      case LogLevel.important:
        return Container(
            margin: const EdgeInsets.only(top: 6),
            color: Colors.greenAccent,
            child: Text(msg,
                style: const TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold)));

      case LogLevel.warn:
        return Container(
            margin: const EdgeInsets.only(top: 6),
            color: Colors.yellow,
            child: Text(msg, style: const TextStyle(color: Colors.black)));

      case LogLevel.error:
        return Container(
            margin: const EdgeInsets.only(top: 6),
            color: Colors.red,
            child: Text(
              '$msg${log.stackTrace == null ? '' : '\n${log.stackTrace}'}',
              style: const TextStyle(color: Colors.white),
            ));

      default: // LogLevel.fatal:
        return Container(
            margin: const EdgeInsets.only(top: 6),
            color: Colors.purple,
            child: Text(
              '$msg${log.stackTrace == null ? '' : '\n${log.stackTrace}'}',
              style: const TextStyle(color: Colors.white),
            ));
    }
  }
}
