import 'package:flutter/material.dart';
//
import 'package:chaostours/model/model_task.dart';
import 'package:chaostours/model/model_alias.dart';
import 'package:chaostours/model/model_trackpoint.dart';
import 'package:chaostours/globals.dart';
import 'package:chaostours/widget/widgets.dart';
import 'package:chaostours/model/model_checkbox.dart';
import 'package:chaostours/util.dart' as util;

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
        icon: const Icon(size: 50, Icons.done_outline_rounded));
  }

  Widget divider() {
    return const Divider(
        thickness: 1, indent: 10, endIndent: 10, color: Colors.blueGrey);
  }

  Widget recentTrackPointInfo(ModelTrackPoint tp) {
    List<String> alias =
        tp.idAlias.map((id) => ModelAlias.getAlias(id).alias).toList();

    List<String> tasks =
        tp.idTask.map((id) => ModelTask.getTask(id).task).toList();
    String day =
        '${Globals.weekDays[tp.timeStart.weekday]}. den ${tp.timeStart.day}.${tp.timeStart.month}.${tp.timeStart.year}';
    String time = '${tp.timeStart.hour}:${tp.timeStart.minute}';
    String duration = util.timeElapsed(tp.timeStart, tp.timeEnd, false);

    ///
    return Container(
        padding: const EdgeInsets.all(10),
        child: ListBody(children: [
          Center(
              heightFactor: 2,
              child: alias.isEmpty
                  ? Text('OSM Addr: ${tp.address}')
                  : Text('Alias: - ${alias.join('\n- ')}')),
          Text('Am $day um $time\nfür $duration'),
          Text(
              'Aufgaben:${tasks.isEmpty ? ' -' : '\n   - ${tasks.join('\n   - ')}'}'),
          Text('Notizen ${tp.notes}')
        ]));
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
        body: ListView(children: [
          backButton(context),
          recentTrackPointInfo(ModelTrackPoint.editTrackPoint),
          Container(
              padding: const EdgeInsets.all(10),
              child: TextField(
                  decoration: const InputDecoration(
                      label: Text('Notizen'),
                      contentPadding: EdgeInsets.all(2)),
                  //expands: true,
                  maxLines: null,
                  minLines: 5,
                  controller: TextEditingController(
                      text: ModelTrackPoint.editTrackPoint.notes),
                  onChanged: (String? s) =>
                      ModelTrackPoint.pendingTrackPoint.notes = s ?? '')),
          divider(),
          ...checkBoxes
        ]));
  }
}
