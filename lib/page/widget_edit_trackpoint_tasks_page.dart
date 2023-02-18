import 'package:flutter/material.dart';
//
import 'package:chaostours/model/model_task.dart';
import 'package:chaostours/model/model_alias.dart';
import 'package:chaostours/model/model_trackpoint.dart';
import 'package:chaostours/globals.dart';
import 'package:chaostours/widget/widgets.dart';
import 'package:chaostours/model/model_checkbox.dart';
import 'package:chaostours/util.dart' as util;
import 'package:chaostours/shared/shared.dart';
import 'package:chaostours/event_manager.dart';
import 'package:chaostours/logger.dart';

///
/// CheckBox list
///
class WidgetEditTrackpointTasks extends StatefulWidget {
  const WidgetEditTrackpointTasks({super.key});

  @override
  State<StatefulWidget> createState() => _WidgetAddTasksState();
}

class _WidgetAddTasksState extends State<WidgetEditTrackpointTasks> {
  Logger logger = Logger.logger<WidgetEditTrackpointTasks>();
  BuildContext? _context;
  static TextEditingController _controller =
      TextEditingController(text: ModelTrackPoint.editTrackPoint.notes);
  @override
  void initState() {
    EventManager.listen<EventOnTrackingStatusChanged>(onTrackingStatusChanged);
    super.initState();
  }

  @override
  void dispose() {
    EventManager.remove<EventOnTrackingStatusChanged>(onTrackingStatusChanged);
    super.dispose();
  }

  void onTrackingStatusChanged(EventOnTrackingStatusChanged e) {
    if (ModelTrackPoint.pendingTrackPoint == ModelTrackPoint.editTrackPoint) {
      if (_context != null) {
        Navigator.pop(_context!);
      }
    }
  }

  ///
  Widget createCheckbox(CheckboxModel model) {
    TextStyle style = TextStyle(
        color: model.enabled ? Colors.black : Colors.grey,
        decoration:
            model.deleted ? TextDecoration.lineThrough : TextDecoration.none);

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
          if (ModelTrackPoint.editTrackPoint.id > 0) {
            Shared shared = Shared(SharedKeys.updateTrackPointQueue);
            shared.loadList().then((_) {
              var q = _ ??= [];
              q.add(ModelTrackPoint.editTrackPoint.toString());
              shared.saveList(q);
            });
          }
        },
        icon: const Icon(size: 50, Icons.done_outline_rounded));
  }

  Widget divider() {
    return const Divider(
        thickness: 1, indent: 10, endIndent: 10, color: Colors.blueGrey);
  }

  Widget trackPointInfo(ModelTrackPoint tp) {
    var alias = tp.idAlias.map((id) => ModelAlias.getAlias(id).alias).toList();
    var tasks = tp.idTask.map((id) => ModelTask.getTask(id).task).toList();

    ///
    return Container(
        padding: const EdgeInsets.all(10),
        child: ListBody(children: [
          Center(
              heightFactor: 2,
              child: alias.isEmpty
                  ? Text('OSM: ${tp.address}')
                  : Text('Alias: - ${alias.join('\n- ')}')),
          Text(AppWidgets.timeInfo(tp.timeStart, tp.timeEnd)),
          Text(
              'Aufgaben:${tasks.isEmpty ? ' -' : '\n   - ${tasks.join('\n   - ')}'}')
        ]));
  }

  @override
  Widget build(BuildContext context) {
    _context = context;
    var referenceList = ModelTrackPoint.editTrackPoint.idTask;
    var checkBoxes = <Widget>[];
    for (var t in ModelTask.getAll()) {
      if (!t.deleted) {
        checkBoxes.add(createCheckbox(CheckboxModel(
            idReference: t.id,
            referenceList: referenceList,
            deleted: t.deleted,
            title: t.task,
            subtitle: t.notes)));
      }
    }

    var activeTrackPointInfo = <Widget>[];
    if (ModelTrackPoint.pendingTrackPoint == ModelTrackPoint.editTrackPoint) {
      activeTrackPointInfo.add(Container(
          padding: const EdgeInsets.all(10),
          child: const Text(
              'Achtung! Sie bearbeiten einen aktiven Haltepunkt.\n'
              'Panel schließt sobald sich der Fahren/Halten Status ändert.',
              style: TextStyle(color: Colors.red))));
    }
    var body = ListView(children: [
      ...activeTrackPointInfo,
      backButton(context),
      trackPointInfo(ModelTrackPoint.editTrackPoint),
      Container(
          padding: const EdgeInsets.all(10),
          child: TextField(
              decoration: const InputDecoration(
                  label: Text('Notizen'), contentPadding: EdgeInsets.all(2)),
              //expands: true,
              maxLines: null,
              minLines: 5,
              controller: _controller,
              onChanged: (String? s) {
                ModelTrackPoint.pendingTrackPoint.notes = s ?? '';
                logger.log('$s');
              })),
      divider(),
      ...checkBoxes
    ]);
    return AppWidgets.scaffold(context, body: body);
  }
}
