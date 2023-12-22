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
import 'package:chaostours/conf/app_user_settings.dart';
import 'package:chaostours/database/cache.dart';
import 'package:flutter/material.dart';
//

Codec<String, String> base64Codec() => utf8.fuse(base64);

double fileSize(File file) {
  double mb = file.lengthSync() / (1024 * 1024);
  return mb;
}

String twoDigits(int n) => n.toString().padLeft(2, "0");

String formatDuration(Duration duration) {
  String negativeSign = duration.isNegative ? '-' : '';
  String twoDigitHours = twoDigits(duration.inHours.remainder(24).abs());
  String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60).abs());
  String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60).abs());
  return "$negativeSign${twoDigits(duration.inDays)}d:${twoDigitHours}h:${twoDigitMinutes}m:${twoDigitSeconds}s";
}

String formatTimeRange(DateTime timeStart, DateTime timeEnd) {
  return '${twoDigits(timeStart.hour)}:${twoDigits(timeStart.minute)}::${twoDigits(timeStart.second)}'
      ' - ${twoDigits(timeEnd.hour)}:${twoDigits(timeEnd.minute)}::${twoDigits(timeEnd.second)}';
}

String formatDate(DateTime t) {
  String date;
  if (StaticCache.dateFormat == DateFormat.yyyymmdd) {
    date = '${t.year}.${twoDigits(t.month)}.${twoDigits(t.day)}';
  } else {
    date = '${t.day}.${twoDigits(t.month)}.${twoDigits(t.year)}';
  }
  return '$date - ${twoDigits(t.hour)}:${twoDigits(t.minute)}::${twoDigits(t.second)}';
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
  Function(bool? toggle)? onToggle;
  CheckboxController({
    required this.idReference,
    required this.referenceList,
    this.title = '',
    this.onToggle,
    this.checked = false,
    this.subtitle = '',
    this.isActive = true,
  }) {
    checked = referenceList.contains(idReference);
  }

  /// this method is called from CheckBox
  void toggle(bool? state) {
    if (!isActive) {
      return;
    }
    checked = state ?? false;
    if (checked) {
      if (!referenceList.contains(idReference)) {
        referenceList.add(idReference);
      }
    } else {
      referenceList.removeWhere((i) => i == idReference);
    }
    onToggle?.call(checked);
  }

  /// render multiple checkboxes
  static Widget createCheckboxListTile(CheckboxController model) {
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
      leading: Checkbox(value: model.checked, onChanged: model.toggle),
    );
  }

  static Widget createCheckbox(CheckboxController model) {
    return Checkbox(value: model.checked, onChanged: model.toggle);
  }
}
