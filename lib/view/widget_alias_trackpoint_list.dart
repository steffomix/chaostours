import 'package:chaostours/event_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:chaostours/gps.dart';
import 'package:flutter/services.dart';

///
import 'package:chaostours/globals.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/util.dart';
import 'package:chaostours/screen.dart';
import 'package:chaostours/view/app_widgets.dart';
import 'package:chaostours/model/model_trackpoint.dart';
import 'package:chaostours/model/model_alias.dart';
import 'package:chaostours/model/model_task.dart';
import 'package:chaostours/model/model_user.dart';

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
  String _search = '';
  TextEditingController controller = TextEditingController();
  late ModelAlias _alias;

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

  Widget map(context) {
    Screen screen = Screen(context);
    return SizedBox(
        width: screen.width,
        height: 25,
        child: IconButton(
            icon: Icon(Icons.map),
            onPressed: () {
              var gps = GPS.lastGps!;
              var lat = gps.lat;
              var lon = gps.lon;
              var lat1 = _alias.lat;
              var lon1 = _alias.lon;
              var url = 'https://www.google.com/maps/dir/?'
                  'api=1&origin=$lat%2c$lon&destination=$lat1%2c$lon1&'
                  'travelmode=driving';

              final intent = AndroidIntent(
                  action: 'action_view',
                  data: url,
                  package: 'com.google.android.apps.maps');
              intent.launch();
            }));
  }

  Widget search(BuildContext context) {
    return TextField(
        controller: controller,
        minLines: 1,
        maxLines: 1,
        decoration: const InputDecoration(
            icon: Icon(Icons.search, size: 30), border: InputBorder.none),
        onChanged: (value) {
          _search = value.toLowerCase();
          setState(() {});
        });
  }

  Widget alias(BuildContext context) {
    var alias = ModelAlias.getAlias(_id);
    var type = alias.status;
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
                    arguments: _id)
                .then((_) {
              setState(() {});
            });
          },
        ));
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
              Navigator.pushNamed(context, AppRoutes.editTrackingTasks.route)
                  .then((_) {
                setState(() {});
              });
            },
          )),
    ];

    if (users.isNotEmpty) {
      widgets.add(ListTile(
        title: const Text('Personal'),
        subtitle: Text('- ${users.join('\n- ')}'),
      ));
    }

    if (tasks.isNotEmpty) {
      widgets.add(ListTile(
        title: const Text('Arbeiten'),
        subtitle: Text('- ${tasks.join('\n- ')}'),
      ));
    }

    if (tp.notes.trim().isNotEmpty) {
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

  Widget body(BuildContext context) {
    return ListView.builder(
        itemCount: _tpList.length + 1,
        itemBuilder: (context, id) {
          if (id == 0) {
            return Container(
                padding: const EdgeInsets.only(bottom: 15),
                child: Column(children: [
                  map(context),
                  search(context),
                  alias(context),
                  AppWidgets.divider()
                ]));
          } else {
            return trackPoint(context, _tpList[id - 1]);
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    _id = ModalRoute.of(context)!.settings.arguments as int;

    _alias = ModelAlias.getAlias(_id);

    if (_search.trim().isEmpty) {
      _tpList = ModelTrackPoint.byAlias(_id);
    } else {
      _tpList.clear();

      /// pre-search idUser and idTask
      List<int> hasTask = [];
      List<int> hasUser = [];
      for (var item in ModelTask.getAll()) {
        if (item.task.toLowerCase().contains(_search)) {
          hasTask.add(item.id);
        }
      }
      for (var item in ModelUser.getAll()) {
        if (item.user.toLowerCase().contains(_search)) {
          hasUser.add(item.id);
        }
      }

      /// begin search
      for (var item in ModelTrackPoint.byAlias(_id)) {
        var found = false;
        if (item.notes.toLowerCase().contains(_search)) {
          _tpList.add(item);
          continue;
        }
        for (var id in hasTask) {
          if (item.idTask.contains(id)) {
            _tpList.add(item);
            found = true;
            break;
          }
        }
        if (!found) {
          for (var id in hasUser) {
            if (item.idUser.contains(id)) {
              _tpList.add(item);
              break;
            }
          }
        }
      }
    }

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
      return Scaffold(appBar: AppWidgets.appBar(context), body: body(context));
    }
  }
}
