import 'package:chaostours/data_bridge.dart';
import 'package:chaostours/model/model_alias.dart';
import 'package:chaostours/model/model_task.dart';
import 'package:chaostours/model/model_user.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/globals.dart';
import 'package:chaostours/util.dart';

class TrackPointData {
  late DateTime tStart;
  late DateTime tEnd;
  late PendingGps gpslastStatusChange;
  late int distanceStanding;
  late int distanceStandingFromBorder;
  late int standingRadius;
  late double distanceMoving;
  List<ModelAlias> aliasList = [];
  late String aliasText;
  List<ModelUser> userList = [];
  late String tasksText;
  List<ModelTask> taskList = [];
  late String usersText;
  late String trackPointNotes;
  late String durationText;
  late String addressText;
  late String notes;

  TrackPointData() {
    DataBridge bridge = DataBridge.instance;

    tStart = (bridge.trackPointGpslastStatusChange?.time ??
            bridge.gpsPoints.last.time)
        .subtract(Globals.timeRangeTreshold);
    tEnd = DateTime.now();
    gpslastStatusChange =
        bridge.trackPointGpslastStatusChange ?? bridge.gpsPoints.last;

    distanceMoving = bridge.gpsPoints.isEmpty
        ? 0.0
        : (GPS.distanceOverTrackList(bridge.gpsPoints) / 10).round() / 100;
    try {
      GPS gps;
      int radius;
      if (bridge.trackPointAliasIdList.isNotEmpty) {
        var alias = ModelAlias.getAlias(bridge.trackPointAliasIdList.first);
        gps = GPS(alias.lat, alias.lon);
        radius = alias.radius;
      } else {
        gps = bridge.trackPointGpsStartStanding!;
        radius = Globals.distanceTreshold;
      }
      distanceStanding = bridge.gpsPoints.isEmpty
          ? 0
          : GPS
              .distance(
                  bridge.calcGpsPoints.isNotEmpty
                      ? bridge.calcGpsPoints.first
                      : bridge.gpsPoints.first,
                  gps)
              .round();
      distanceStandingFromBorder = radius - distanceStanding;
      standingRadius = radius;
    } catch (e) {
      distanceStanding = 0;
    }
    aliasList = bridge.trackPointAliasIdList.isEmpty
        ? []
        : bridge.trackPointAliasIdList
            .map((id) => ModelAlias.getAlias(id))
            .toList();

    userList = bridge.trackPointUserIdList.isEmpty
        ? []
        : bridge.trackPointUserIdList
            .map((id) => ModelUser.getUser(id))
            .toList();

    taskList = bridge.trackPointTaskIdList.isEmpty
        ? []
        : bridge.trackPointTaskIdList
            .map((id) => ModelTask.getTask(id))
            .toList();

    aliasText = aliasList.isEmpty
        ? ' ---'
        : '${aliasList.length == 1 ? '-' : '-->'} ${aliasList.map((e) {
              return e.alias;
            }).toList().join('\n- ')}';

    tasksText = taskList.isEmpty
        ? ' ---'
        : taskList
            .map((e) {
              return '- ${e.task}';
            })
            .toList()
            .join('\n');

    usersText = userList.isEmpty
        ? ' ---'
        : userList
            .map((e) {
              return '- ${e.user}';
            })
            .toList()
            .join('\n');

    trackPointNotes = bridge.trackPointUserNotes;
    durationText = timeElapsed(tStart, tEnd, false);
    addressText = bridge.currentAddress.isEmpty ? '---' : bridge.currentAddress;
  }
}
