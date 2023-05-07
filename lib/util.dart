import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
//

Codec<String, String> base64Codec() => utf8.fuse(base64);

double fileSize(File file) {
  double mb = file.lengthSync() / (1024 * 1024);
  return mb;
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
  String title;
  late bool checked;
  bool deleted;
  String subtitle;
  bool enabled;
  int group;
  VoidCallback? onToggle;
  List<int> referenceList;
  CheckboxController({
    required this.idReference,
    required this.referenceList,
    required this.title,
    this.group = 0,
    this.subtitle = '',
    this.deleted = false,
    this.onToggle,
    this.enabled = true,
  }) {
    checked = referenceList.contains(idReference);
  }
  void toggle() {
    if (enabled) checked = !checked;
    if (checked) {
      if (!referenceList.contains(idReference)) referenceList.add(idReference);
    } else {
      referenceList.removeWhere((i) => i == idReference);
    }
  }

  void enable(bool state) => enabled = state;
  bool get isEnabled => enabled;
  VoidCallback? handler() {
    if (enabled) {
      toggle();
      onToggle?.call();
    } else {
      return null;
    }
  }
}

/// render multiple checkboxes
Widget createCheckbox(State widget, CheckboxController model) {
  TextStyle style = TextStyle(
      color: model.enabled ? Colors.black : Colors.grey,
      decoration:
          model.deleted ? TextDecoration.lineThrough : TextDecoration.none);

  return ListTile(
    subtitle: model.subtitle.trim().isEmpty
        ? null
        : Text(model.subtitle, style: const TextStyle(color: Colors.grey)),
    title: Text(
      model.title,
      style: style,
    ),
    leading: Checkbox(
      value: model.checked,
      onChanged: (_) {
        widget.setState(
          () {
            model.handler()?.call();
          },
        );
      },
    ),
    onTap: () {
      widget.setState(
        () {
          model.handler()?.call();
        },
      );
    },
  );
}
