import 'package:flutter/material.dart';
//
import 'package:chaostours/model/model_task.dart';
import 'package:chaostours/model/model_trackpoint.dart';
import 'package:chaostours/widget/widget_drawer.dart';
import 'package:chaostours/widget/widgets.dart';
import 'package:chaostours/widget/widget_bottom_navbar.dart';

class CheckboxModel {
  final int id;
  String title;
  bool checked;
  String notes = '';
  bool shouldToggle = true;
  VoidCallback? onToggle;
  List<int> tasks = ModelTrackPoint.editTrackPoint.idTask;
  CheckboxModel({
    required this.id,
    required this.title,
    required this.checked,
    this.notes = '',
    this.onToggle,
    this.shouldToggle = true,
  }) {
    onToggle = toggle;
  }
  void toggle() {
    if (shouldToggle) checked = !checked;
    if (checked) {
      if (!tasks.contains(id)) tasks.add(id);
    } else {
      tasks.removeWhere((i) => i == id);
    }
  }

  void enable(bool state) => shouldToggle = state;
  bool get isEnabled => shouldToggle;
  VoidCallback? handler() {
    if (shouldToggle) {
      return onToggle;
    } else {
      return null;
    }
  }
}

///
/// CheckBox list
///
class WidgetEditTrackpointTasks extends StatefulWidget {
  const WidgetEditTrackpointTasks({super.key});

  @override
  State<StatefulWidget> createState() => _WidgetAddTasksState();
}

class _WidgetAddTasksState extends State<WidgetEditTrackpointTasks> {
  ///
  Widget createCheckbox(CheckboxModel model) {
    TextStyle style = model.shouldToggle
        ? const TextStyle(color: Colors.black)
        : const TextStyle(color: Colors.grey);
    return ListTile(
      subtitle: Text(model.notes, style: const TextStyle(color: Colors.grey)),
      title: Text(
        model.title,
        style: style,
      ),
      leading: Checkbox(
        value: model.checked,
        onChanged: (_) {
          setState(
            () {
              model.handler()?.call();
              //model.toggle();
              //swapEnabledGroup(checkboxes[2].value);
            },
          );
        },
      ),
      onTap: () {
        setState(
          () {
            //swapEnabledGroup(checkboxes[2].value);
            model.handler()?.call();
            //model.toggle();
          },
        );
      },
    );
  }

  Widget backButton(BuildContext context) {
    return IconButton(
        onPressed: () {
          // ModelTrackPoint.pendingTrackPoint = ModelTrackPoint.editTrackPoint;
          Navigator.pop(context);
        },
        icon: const Icon(Icons.done_outline_rounded));
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> checkBoxes = ModelTask.getAll().map((ModelTask task) {
      return createCheckbox(CheckboxModel(
          id: task.id,
          checked: ModelTrackPoint.editTrackPoint.idTask.contains(task.id),
          title: task.task,
          notes: task.notes));
    }).toList();
    return Widgets.scaffold(
        context, ListView(children: [backButton(context), ...checkBoxes]));
  }
}
