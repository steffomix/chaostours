import 'package:chaostours/event_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

///
import 'package:chaostours/globals.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/event_manager.dart';
import 'package:chaostours/util.dart';
import 'package:chaostours/view/app_widgets.dart';
import 'package:chaostours/model/model_trackpoint.dart';
import 'package:chaostours/model/model_alias.dart';
import 'package:chaostours/model/model_task.dart';
import 'package:chaostours/model/model_user.dart';
import 'package:flutter/services.dart';

class WidgetAliasTrackpoint extends StatefulWidget {
  const WidgetAliasTrackpoint({super.key});

  @override
  State<WidgetAliasTrackpoint> createState() => _WidgetAliasTrackpoint();
}

class _WidgetAliasTrackpoint extends State<WidgetAliasTrackpoint> {
  static final Logger logger = Logger.logger<WidgetAliasTrackpoint>();
  static int mode = 0;
  int _id = 0;
  List _tpList = <ModelTrackPoint>[];

  List trackPointList = <ModelTrackPoint>[];
  @override
  void initState() {
    EventManager.listen<EventOnTrackingStatusChanged>(onNewTrackpoint);
    loadTrackPoints();
    super.initState();
  }

  @override
  void dispose() {
    EventManager.remove<EventOnTrackingStatusChanged>(onNewTrackpoint);
    super.dispose();
  }

  void onNewTrackpoint(EventOnTrackingStatusChanged e) {
    setState(() {});
  }

  void loadTrackPoints() {
    ModelTrackPoint.open().then((_) {
      setState(() {});
    });
  }

  Widget alias(BuildContext context) {
    var alias = ModelAlias.getAlias(_id);
    var type = alias.status;
    Color color;
    if (type == AliasStatus.privat) {
      color = AppColors.aliasPrivate.color;
    } else if (type == AliasStatus.restricted) {
      color = AppColors.aliasRestricted.color;
    } else {
      color = AppColors.aliasPubplic.color;
    }
    return ListTile(
        title: Text(alias.alias),
        subtitle: Text(alias.notes),
        leading: Text('${_tpList.length}x',
            style: TextStyle(
                backgroundColor: AppColors.aliasStatusColor(alias.status))),
        trailing: IconButton(
          icon: Icon(Icons.edit, size: 30, color: AppColors.black.color),
          onPressed: () {
            Navigator.pushNamed(context, AppRoutes.editAlias.route,
                arguments: _id);
          },
        ));
  }

  Widget body(BuildContext context) {
    return ListView.builder(
        itemCount: _tpList.length + 1,
        itemBuilder: (context, id) {
          if (id == 0) {
            return alias(context);
          } else {
            return trackPoint(context, _tpList[id - 1]);
          }
        });
  }

  Widget trackPoint(BuildContext context, ModelTrackPoint tp) {
    var date = '${Globals.weekDays[tp.timeStart.weekday]}. '
        '${tp.timeStart.day}.${tp.timeStart.month}.${tp.timeStart.year}';
    var dur = timeElapsed(tp.timeStart, tp.timeEnd, false);
    var time =
        'von ${tp.timeStart.hour}:${tp.timeStart.minute} bis ${tp.timeEnd.hour}:${tp.timeEnd.minute}\n($dur)';
    Iterable<String> tasks = tp.idTask.map((id) => ModelTask.getTask(id).task);
    Iterable<String> users = tp.idUser.map((id) => ModelUser.getUser(id).user);
    List<Widget> widgets = [
      ListTile(
          title: Text(date),
          subtitle: Text(time),
          trailing: IconButton(
            icon: const Icon(Icons.edit, size: 30),
            onPressed: () {
              ModelTrackPoint.editTrackPoint = tp;
              Navigator.pushNamed(context, AppRoutes.editTrackingTasks.route);
            },
          )),
      ListTile(
        title: const Text('Personal'),
        subtitle: Text(users.isEmpty ? '-' : '- ${users.join('\n- ')}'),
      ),
      ListTile(
        title: const Text('Aufgaben'),
        subtitle: Text(tasks.isEmpty ? '-' : '- ${tasks.join('\n- ')}'),
      )
    ];
    if (true) {
      widgets.add(ListTile(
          title: const Text('Notizen'),
          subtitle: Text(tp.notes),
          trailing: IconButton(
              icon: const Icon(Icons.copy),
              onPressed: () =>
                  Clipboard.setData(ClipboardData(text: tp.notes.trim())))));
    }
    widgets.add(AppWidgets.divider());
    return Column(children: widgets);
  }

  @override
  Widget build(BuildContext context) {
    _id = ModalRoute.of(context)!.settings.arguments as int;

    _tpList = ModelTrackPoint.byAlias(_id);

    if (ModelTrackPoint.length == 0) {
      return Scaffold(
          appBar: AppWidgets.appBar(context),
          body: Container(
              alignment: Alignment.center,
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text('Warte auf / lade Haltepunkte\n\n'),
                    AppWidgets.loading(),
                  ])));
    } else {
      return Scaffold(
          appBar: AppWidgets.appBar(context),
          body: body(context),
          bottomNavigationBar: BottomNavigationBar(
              selectedFontSize: 14,
              unselectedFontSize: 14,
              backgroundColor: AppColors.yellow.color,
              selectedItemColor: AppColors.black.color,
              unselectedItemColor: AppColors.black.color,
              items: const [
                // 0 alphabethic
                BottomNavigationBarItem(
                    icon: Icon(Icons.timer), label: 'Zuletzt besucht'),
                // 1 nearest
                BottomNavigationBarItem(
                    icon: Icon(Icons.near_me), label: 'In Nähe'),
              ],
              onTap: (int id) {
                var m = mode;
              }));
    }
  }
}
