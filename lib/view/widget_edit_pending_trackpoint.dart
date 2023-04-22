import 'package:flutter/material.dart';

///
import 'package:chaostours/view/app_widgets.dart';
import 'package:chaostours/util.dart';
import 'package:chaostours/data_bridge.dart';
import 'package:chaostours/cache.dart';
import 'package:chaostours/event_manager.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/model/model_user.dart';
import 'package:chaostours/model/model_task.dart';
import 'package:chaostours/model/model_alias.dart';

///
/// CheckBox list
///
class WidgetEditPendingTrackPoint extends StatefulWidget {
  const WidgetEditPendingTrackPoint({super.key});

  @override
  State<StatefulWidget> createState() => _WidgetAddTasksState();
}

class _WidgetAddTasksState extends State<WidgetEditPendingTrackPoint> {
  Logger logger = Logger.logger<WidgetEditPendingTrackPoint>();

  /// EventListener
  BuildContext? _context;

  DataBridge bridge = DataBridge.instance;

  /// editable fields
  List<int> tpTasks = [...DataBridge.instance.trackPointTaskIdList];
  List<int> tpUsers = [...DataBridge.instance.trackPointUserIdList];
  TextEditingController tpNotes =
      TextEditingController(text: DataBridge.instance.trackPointUserNotes);

  /// modify
  ValueNotifier<bool> modified = ValueNotifier<bool>(false);
  void modify() {
    modified.value = true;
    setState(() {});
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
    _context ?? Navigator.pop(_context!);
  }

  /// current trackpoint
  Widget trackPointInfo(BuildContext context) {
    List<String> alias = bridge.trackPointAliasIdList
        .map((id) => ModelAlias.getAlias(id).alias)
        .toList();
    List<String> tasks =
        tpTasks.map((id) => ModelTask.getTask(id).task).toList();
    DateTime tStart = bridge.trackPointGpsStartStanding?.time ?? DateTime.now();
    DateTime tEnd = DateTime.now();
    return Container(
        padding: const EdgeInsets.all(10),
        child: ListBody(children: [
          Center(
              heightFactor: 2,
              child: alias.isEmpty
                  ? Text('OSM: ${bridge.currentAddress}')
                  : Text('Alias: ${alias.join('\n- ')}')),
          Text(AppWidgets.timeInfo(tStart, tEnd)),
          Text(
              'Aufgaben:${tasks.isEmpty ? ' -' : '\n   - ${tasks.join('\n   - ')}'}')
        ]));
  }

  List<Widget> taskCheckboxes(context) {
    var referenceList = tpTasks;
    var checkBoxes = <Widget>[];
    for (var model in ModelTask.getAll()) {
      if (!model.deleted) {
        checkBoxes.add(createCheckbox(
            this,
            CheckboxController(
                idReference: model.id,
                referenceList: referenceList,
                deleted: model.deleted,
                title: model.task,
                subtitle: model.notes,
                onToggle: () {
                  modify();
                })));
      }
    }
    return checkBoxes;
  }

  List<Widget> userCheckboxes(context) {
    var referenceList = tpUsers;
    var checkBoxes = <Widget>[];
    for (var model in ModelUser.getAll()) {
      if (!model.deleted) {
        checkBoxes.add(createCheckbox(
            this,
            CheckboxController(
                idReference: model.id,
                referenceList: referenceList,
                deleted: model.deleted,
                title: model.user,
                subtitle: model.notes,
                onToggle: () {
                  modify();
                })));
      }
    }
    return checkBoxes;
  }

  bool dropdownUserIsOpen = false;
  Widget dropdownUser(context) {
    /// render selected users
    List<String> userList = [];
    for (var model in ModelUser.getAll()) {
      if (tpUsers.contains(model.id)) {
        userList.add(model.user);
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
            controller: tpNotes,
            onChanged: (String? s) {
              //bridge.trackPointUserNotes = s?.trim() ?? '';
              modify();
            }));
  }

  Widget warning(BuildContext context) {
    return Container(
        padding: const EdgeInsets.all(10),
        child: const Text(
            'Achtung! Sie bearbeiten einen aktiven, temporären, noch nicht gespeicherten Haltepunkt.\n'
            'Änderungen werden möglicherweise nicht gespeichert oder in den nachfolgenden Haltepunkt übernommen',
            style: TextStyle(color: Colors.red)));
  }

  ///
  @override
  Widget build(BuildContext context) {
    /// required for EventListener
    _context = context;

    var body = ListView(children: [
      //warning(context),

      /// current Trackpoint time info
      trackPointInfo(context),
      AppWidgets.divider(),
      dropdownTasks(context),
      AppWidgets.divider(),
      dropdownUser(context),
      AppWidgets.divider(),
      notes(context),
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
            if (id == 0) {
              if (modified.value) {
                Future.microtask(() async {
                  bridge.trackPointTaskIdList = await Cache.setValue<List<int>>(
                      CacheKeys.cacheBackgroundTaskIdList, tpTasks);
                  bridge.trackPointUserIdList = await Cache.setValue<List<int>>(
                      CacheKeys.cacheBackgroundUserIdList, tpUsers);
                  bridge.trackPointUserNotes = await Cache.setValue<String>(
                      CacheKeys.cacheBackgroundTrackPointUserNotes,
                      tpNotes.text);
                }).then((_) {
                  if (mounted) {
                    modified.value = false;
                    setState(() {});
                  }
                });
              }
            } else {
              Navigator.pop(context);
            }
          }),
    );
  }
}
