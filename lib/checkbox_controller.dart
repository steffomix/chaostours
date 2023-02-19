import 'package:flutter/material.dart';
import 'package:chaostours/model/model_trackpoint.dart';

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
    onToggle = toggle;
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
      return onToggle;
    } else {
      return null;
    }
  }
}
