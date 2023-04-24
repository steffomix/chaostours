import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
//
import 'package:chaostours/model/model_user.dart';
import 'package:chaostours/model/model_task.dart';
import 'package:chaostours/model/model_alias.dart';
import 'package:chaostours/model/model_trackpoint.dart';
import 'package:chaostours/view/app_widgets.dart';
import 'package:chaostours/checkbox_controller.dart';
import 'package:chaostours/util.dart';
import 'package:chaostours/logger.dart';

///
/// CheckBox list
///
class WidgetEditTrackPoint extends StatefulWidget {
  const WidgetEditTrackPoint({super.key});

  @override
  State<StatefulWidget> createState() => _WidgetAddTasksState();
}

class _WidgetAddTasksState extends State<WidgetEditTrackPoint> {
  Logger logger = Logger.logger<WidgetEditTrackPoint>();

  /// editable fields
  List<int> tpTasks = [];
  List<int> tpUsers = [];
  TextEditingController tpNotes = TextEditingController();

  late ModelTrackPoint trackPoint;

  bool initialized = false;

  /// modify
  ValueNotifier<bool> modified = ValueNotifier<bool>(false);
  void modify() {
    modified.value = true;
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// current trackpoint
  Widget trackPointInfo(BuildContext context) {
    var alias =
        trackPoint.idAlias.map((id) => ModelAlias.getAlias(id).alias).toList();
    var tasks = tpTasks.map((id) => ModelTask.getTask(id).task).toList();

    return Container(
        padding: const EdgeInsets.all(10),
        child: ListBody(children: [
          Center(
              heightFactor: 2,
              child: alias.isEmpty
                  ? Text('OSM: ${trackPoint.address}')
                  : Text('Alias: ${alias.join('\n- ')}')),
          Text(AppWidgets.timeInfo(trackPoint.timeStart, trackPoint.timeEnd)),
          Text(
              'Arbeiten:${tasks.isEmpty ? ' -' : '\n   - ${tasks.join('\n   - ')}'}')
        ]));
  }

  List<Widget> taskCheckboxes(context) {
    var referenceList = tpTasks;
    var checkBoxes = <Widget>[];
    for (var tp in ModelTask.getAll()) {
      if (!tp.deleted) {
        checkBoxes.add(createCheckbox(
            this,
            CheckboxController(
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
    var referenceList = tpUsers;
    var checkBoxes = <Widget>[];
    for (var tp in ModelUser.getAll()) {
      if (!tp.deleted) {
        checkBoxes.add(createCheckbox(
            this,
            CheckboxController(
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
      if (tpUsers.contains(item.id)) {
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
      if (tpTasks.contains(item.id)) {
        taskList.add(item.task);
      }
    }
    String tasks = taskList.isNotEmpty ? '\n- ${taskList.join('\n- ')}' : ' - ';

    /// dropdown menu botten with selected tasks
    List<Widget> items = [
      ElevatedButton(
        child: ListTile(
            trailing: const Icon(Icons.menu), title: Text('Arbeiten:$tasks')),
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
            controller: tpNotes,
            onChanged: (String? s) {
              modify();
              logger.log('$s');
            }));
  }

  ///
  @override
  Widget build(BuildContext context) {
    Widget body;
    try {
      if (!initialized) {
        final id = (ModalRoute.of(context)?.settings.arguments ?? 0) as int;
        trackPoint = ModelTrackPoint.byId(id);
        tpTasks = trackPoint.idTask;
        tpUsers = trackPoint.idUser;
        tpNotes.text = trackPoint.notes;
        initialized = true;
      }
      body = ListView(children: [
        /// current Trackpoint time info
        trackPointInfo(context),
        AppWidgets.divider(),
        notes(context),
        AppWidgets.divider(),
        dropdownUser(context),
        AppWidgets.divider(),
        dropdownTasks(context)
      ]);
    } catch (e, stk) {
      body = AppWidgets.loading('No valid ID found');
      Future.delayed(const Duration(milliseconds: 500), () {
        Navigator.pop(context);
      });
    }

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
                    valueListenable: modified,
                    builder: ((context, value, child) {
                      return Icon(Icons.done,
                          size: 30,
                          color: modified.value == true
                              ? AppColors.green.color
                              : AppColors.white54.color);
                    })),
                label: 'Speichern'),
            // 1 nearest
            const BottomNavigationBarItem(
                icon: Icon(Icons.cancel), label: 'Abbrechen'),
          ],
          onTap: (int id) {
            if (id == 0 && modified.value) {
              trackPoint.notes = tpNotes.text;
              ModelTrackPoint.update(trackPoint)
                  .then((_) => Navigator.pop(context));
              Fluttertoast.showToast(msg: 'Trackpoint updated');
            } else {
              Navigator.pop(context);
            }
          }),
    );
  }
}
