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

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
//

Codec<String, String> base64Codec() => utf8.fuse(base64);

double fileSize(File file) {
  double mb = file.lengthSync() / (1024 * 1024);
  return mb;
}

Duration timeDifference(DateTime t1, DateTime t2) {
  var diff = t1.difference(t2);
  if (diff.isNegative) {
    diff = t2.difference(t1);
  }
  return diff;
}

String timeElapsed(DateTime t1, DateTime t2, [bool short = true]) {
  DateTime t0;
  if (t1.difference(t2).isNegative) {
    t0 = t1;
    t1 = t2;
    t2 = t0;
  }
  String s = '';
  int days = t1.difference(t2).inDays;
  t2 = t2.add(Duration(days: days));
  //
  int hours = t1.difference(t2).inHours;
  t2 = t2.add(Duration(hours: hours));
  //
  int minutes = t1.difference(t2).inMinutes;
  t2 = t2.add(Duration(minutes: minutes));
  //
  int seconds = t1.difference(t2).inSeconds;
  t2 = t2.add(Duration(seconds: seconds));
  if (short) {
    s = '$hours:$minutes';
  } else {
    s = '';
    if (days > 0) {
      s += '$days Tage, ';
    }
    if (hours > 0) {
      s += '$hours Stunden, ';
    }
    if (minutes > 0) {
      s += '$minutes Minuten';
    }
    /*
    if (seconds > 0) {
      s += '$seconds Sekunden';
    }
    */
  }

  return s;
}

Duration duration(DateTime t1, DateTime t2) {
  DateTime t0;
  if (t1.difference(t2).isNegative) {
    t0 = t1;
    t2 = t1;
    t1 = t0;
  }
  return t1.difference(t2);
}

String formatDate(DateTime t, [bool short = true]) {
  if (short) {
    return '${t.day}.${t.month}.${t.year} um ${t.hour}:${t.minute}';
  } else {
    return '${t.day}.${t.month}.${t.year} ${t.hour}:${t.minute}::${t.second}:::${t.millisecond}';
  }
}

///
/// Model for multiple checkboxes embedded in a ListTile
/// ```
///   List<Widget> checkBoxes = ModelTask.getAll().map((ModelTask task) {
///     List<int> referenceList = [1,2,3,4];
///     return createCheckbox(CheckboxModel(
///       idReference: task.id,
///       referenceList: referenceList,
///       title: task.task,
///       subtitle: task.subtitle));
///   }).toList();
///
///   ... ListTile using title and subTitle
///   createCheckbox(CheckboxModel model)
///     return Checkbox(
///       value: model.checked,
///       onChanged: (_) {
///         setState(() => model.handler()?.call());
///       },
///     );
///   }
///
/// ```
class CheckboxController {
  final int idReference;
  final List<int> referenceList;
  bool isActive;
  bool checked;
  String title;
  String subtitle;
  int group;
  Function(bool?) onToggle;
  CheckboxController({
    required this.idReference,
    required this.referenceList,
    required this.title,
    this.checked = false,
    this.group = 0,
    this.subtitle = '',
    this.isActive = true,
    required this.onToggle,
  }) {
    checked = referenceList.contains(idReference);
  }
  void toggle() {
    if (!isActive) {
      return;
    }
    checked = !checked;
    if (checked) {
      if (!referenceList.contains(idReference)) referenceList.add(idReference);
    } else {
      referenceList.removeWhere((i) => i == idReference);
    }
    onToggle(checked);
  }
}

/// render multiple checkboxes
Widget createCheckbox(State widget, CheckboxController model) {
  TextStyle style = TextStyle(
      color: model.isActive ? Colors.black : Colors.grey,
      decoration:
          model.isActive ? TextDecoration.none : TextDecoration.lineThrough);

  return ListTile(
    subtitle: model.subtitle.trim().isEmpty
        ? null
        : Text(model.subtitle, style: const TextStyle(color: Colors.grey)),
    title: Text(
      model.title,
      style: style,
    ),
    leading: Checkbox(value: model.checked, onChanged: model.onToggle),
  );
}
