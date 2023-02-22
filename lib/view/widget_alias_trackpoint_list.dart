import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

///
import 'package:chaostours/logger.dart';
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

  List trackPointList = <ModelTrackPoint>[];
  @override
  void initState() {
    loadTrackPoints();
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void loadTrackPoints() {
    ModelTrackPoint.open().then((_) {
      setState(() {});
    });
  }

  Widget alias(BuildContext context) {
    var alias = ModelAlias.getAlias(_id);
    return ListTile(
        leading: Text(alias.alias),
        subtitle: Text(alias.notes),
        trailing: IconButton(
          icon: Icon(Icons.edit, size: 30, color: AppColors.black.color),
          onPressed: () {
            Navigator.pushNamed(context, AppRoutes.editAlias.route,
                arguments: _id);
          },
        ));
  }

  Widget body(BuildContext context) {
    var tpList = ModelTrackPoint.byAlias(_id);
    return ListView.builder(
        itemExtent: 80,
        itemCount: tpList.length + 1,
        itemBuilder: (context, id) {
          if (id == 0) {
            return alias(context);
          } else {
            var tp = tpList[id - 1];
            return Center(
                child: Text(AppWidgets.timeInfo(tp.timeStart, tp.timeEnd)));
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    _id = ModalRoute.of(context)!.settings.arguments as int;

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
