import 'package:flutter/material.dart';
//
import 'package:chaostours/model/model_user.dart';
import 'package:chaostours/model/model_task.dart';
import 'package:chaostours/model/model_alias.dart';
import 'package:chaostours/model/model_trackpoint.dart';
import 'package:chaostours/globals.dart';
import 'package:chaostours/view/app_widgets.dart';
import 'package:chaostours/checkbox_controller.dart';
import 'package:chaostours/util.dart' as util;
import 'package:chaostours/shared.dart';
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

  /// EventListener
  BuildContext? _context;

  /// notes
  ValueNotifier<bool> textModified = ValueNotifier<bool>(false);

  /// edit notes
  static TextEditingController textController =
      TextEditingController(text: ModelTrackPoint.editTrackPoint.notes);

  /// modify
  bool modified = false;
  void modify() {
    modified = true;
  }

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

  /// pop edit window if current Trackpoint
  /// is active (not yet saved) and status changes
  void onTrackingStatusChanged(EventOnTrackingStatusChanged e) {
    if (ModelTrackPoint.pendingTrackPoint == ModelTrackPoint.editTrackPoint) {
      if (_context != null) {
        Navigator.pop(_context!);
      }
    }
  }

  /// render multiple checkboxes
  Widget createCheckbox(CheckboxController model) {
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

  /// current trackpoint
  Widget trackPointInfo(BuildContext context) {
    var tp = ModelTrackPoint.editTrackPoint;
    var alias = tp.idAlias.map((id) => ModelAlias.getAlias(id).alias).toList();
    var tasks = tp.idTask.map((id) => ModelTask.getTask(id).task).toList();

    return Container(
        padding: const EdgeInsets.all(10),
        child: ListBody(children: [
          Center(
              heightFactor: 2,
              child: alias.isEmpty
                  ? Text('OSM: ${tp.address}')
                  : Text('Alias: ${alias.join('\n- ')}')),
          Text(AppWidgets.timeInfo(tp.timeStart, tp.timeEnd)),
          Text(
              'Aufgaben:${tasks.isEmpty ? ' -' : '\n   - ${tasks.join('\n   - ')}'}')
        ]));
  }

  List<Widget> taskCheckboxes(context) {
    var referenceList = ModelTrackPoint.editTrackPoint.idTask;
    var checkBoxes = <Widget>[];
    for (var tp in ModelTask.getAll()) {
      if (!tp.deleted) {
        checkBoxes.add(createCheckbox(CheckboxController(
            idReference: tp.id,
            referenceList: referenceList,
            deleted: tp.deleted,
            title: tp.task,
            subtitle: tp.notes)));
      }
    }
    return checkBoxes;
  }

  List<Widget> userCheckboxes(context) {
    var referenceList = ModelTrackPoint.editTrackPoint.idUser;
    var checkBoxes = <Widget>[];
    for (var tp in ModelUser.getAll()) {
      if (!tp.deleted) {
        checkBoxes.add(createCheckbox(CheckboxController(
            idReference: tp.id,
            referenceList: referenceList,
            deleted: tp.deleted,
            title: tp.user,
            subtitle: tp.notes)));
      }
    }
    return checkBoxes;
  }

  bool dropdownUserIsOpen = false;
  Widget dropdownUser(context) {
    /// render selected users
    List<String> userList = [];
    for (var item in ModelUser.getAll()) {
      if (ModelTrackPoint.editTrackPoint.idUser.contains(item.id)) {
        userList.add(item.user);
      }
    }
    String users = userList.isNotEmpty ? '\n- ${userList.join('\n- ')}' : ' - ';

    /// dropdown menu botten with selected users
    List<Widget> items = [
      ElevatedButton(
        child: ListTile(
            trailing: const Icon(Icons.menu), title: Text('Personal:$users')),
        onPressed: () {
          dropdownUserIsOpen = !dropdownUserIsOpen;
          setState(() {});
        },
      ),
      !dropdownUserIsOpen
          ? const SizedBox.shrink()
          : Column(children: userCheckboxes(context))
    ];

    return ListBody(children: items);
  }

  bool dropdownTasksIsOpen = false;
  Widget dropdownTasks(context) {
    /// render selected tasks
    List<String> taskList = [];
    for (var item in ModelTask.getAll()) {
      if (ModelTrackPoint.editTrackPoint.idTask.contains(item.id)) {
        taskList.add(item.task);
      }
    }
    String tasks = taskList.isNotEmpty ? '\n- ${taskList.join('\n- ')}' : ' - ';

    /// dropdown menu botten with selected tasks
    List<Widget> items = [
      ElevatedButton(
        child: ListTile(
            trailing: const Icon(Icons.menu), title: Text('Aufgaben:$tasks')),
        onPressed: () {
          dropdownTasksIsOpen = !dropdownTasksIsOpen;
          setState(() {});
        },
      ),
      !dropdownTasksIsOpen
          ? const SizedBox.shrink()
          : Column(children: taskCheckboxes(context))
    ];

    /// add items
    if (dropdownTasksIsOpen) {
      items.addAll(taskCheckboxes(context));
    }
    return ListBody(children: items);
  }

  Widget notes(BuildContext context) {
    return Container(
        padding: const EdgeInsets.all(10),
        child: TextField(
            decoration: const InputDecoration(
                label: Text('Notizen'),
                contentPadding: EdgeInsets.all(2),
                border: InputBorder.none),
            //expands: true,
            maxLines: null,
            minLines: 2,
            controller: textController,
            onChanged: (String? s) {
              ModelTrackPoint.pendingTrackPoint.notes = s ?? '';
              textModified.value = true;
              logger.log('$s');
            }));
  }

  Widget warning(BuildContext context) {
    if (ModelTrackPoint.pendingTrackPoint == ModelTrackPoint.editTrackPoint) {
      return Container(
          padding: const EdgeInsets.all(10),
          child: const Text(
              'Achtung! Sie bearbeiten einen aktiven Haltepunkt.\n'
              'Panel schließt sobald sich der Fahren/Halten Status ändert.',
              style: TextStyle(color: Colors.red)));
    }
    return const SizedBox.shrink();
  }

  ///
  @override
  Widget build(BuildContext context) {
    /// required for EventListener
    _context = context;

    var body = ListView(children: [
      warning(context),

      /// current Trackpoint time info
      trackPointInfo(context),
      AppWidgets.divider(),
      notes(context),
      AppWidgets.divider(),
      dropdownUser(context),
      AppWidgets.divider(),
      dropdownTasks(context)
    ]);
    return AppWidgets.scaffold(
      context,
      body: body,
      navBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          fixedColor: AppColors.black.color,
          backgroundColor: AppColors.yellow.color,
          items: [
            // 0 alphabethic
            BottomNavigationBarItem(
                icon: ValueListenableBuilder(
                    valueListenable: textModified,
                    builder: ((context, value, child) {
                      return Icon(Icons.done,
                          size: 30,
                          color: textModified.value == true
                              ? AppColors.green.color
                              : AppColors.white54.color);
                    })),
                label: 'Speichern'),
            // 1 nearest
            const BottomNavigationBarItem(
                icon: Icon(Icons.cancel), label: 'Abbrechen'),
          ],
          onTap: (int id) {
            if (id == 0) {
              ModelAlias.update().then(
                  (_) => AppWidgets.navigate(context, AppRoutes.listAlias));
            } else {
              Navigator.pop(context);
            }
          }),
    );
  }
}
