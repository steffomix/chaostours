import 'package:flutter/material.dart';
//
import 'package:chaostours/model/model_task.dart';
import 'package:chaostours/model/model_trackpoint.dart';
import 'package:chaostours/widget/widgets.dart';
import 'package:chaostours/model/model_checkbox.dart';

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
    TextStyle style = model.enabled
        ? const TextStyle(color: Colors.black)
        : const TextStyle(color: Colors.grey);
    return ListTile(
      subtitle:
          Text(model.subtitle, style: const TextStyle(color: Colors.grey)),
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
            },
          );
        },
      ),
      onTap: () {
        setState(
          () {
            model.handler()?.call();
          },
        );
      },
    );
  }

  Widget backButton(BuildContext context) {
    return IconButton(
        onPressed: () {
          Navigator.pop(context);
        },
        icon: const Icon(Icons.done_outline_rounded));
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> checkBoxes = ModelTask.getAll().map((ModelTask task) {
      List<int> referenceList = ModelTrackPoint.editTrackPoint.idTask;
      return createCheckbox(CheckboxModel(
          idReference: task.id,
          referenceList: referenceList,
          title: task.task,
          subtitle: task.notes));
    }).toList();
    return Widgets.scaffold(context,
        body: ListView(children: [backButton(context), ...checkBoxes]));
  }
}
