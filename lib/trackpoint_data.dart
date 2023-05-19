import 'package:chaostours/data_bridge.dart';
import 'package:chaostours/model/model_trackpoint.dart';
import 'package:chaostours/model/model_alias.dart';
import 'package:chaostours/model/model_task.dart';
import 'package:chaostours/model/model_user.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/globals.dart';
import 'package:chaostours/util.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/view/app_widgets.dart';

class TrackPointData {
  static final Logger logger = Logger.logger<TrackPointData>();
  ModelTrackPoint? tp;
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
  String calendarId = '';
  String calendarEventId = '';

  TrackPointData({this.tp}) {
    DataBridge bridge = DataBridge.instance;

    tStart = tp?.timeStart ??
        (bridge.trackPointGpslastStatusChange?.time ??
            bridge.gpsPoints.last.time.subtract(Globals.timeRangeTreshold));
    tEnd = tp?.timeEnd ?? DateTime.now();
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
    var aliasIds = tp?.idAlias ?? bridge.trackPointAliasIdList;
    aliasList = aliasIds.map((id) => ModelAlias.getAlias(id)).toList();
    // don't sort alias
    aliasText = aliasList.isEmpty
        ? ' ---'
        : '${aliasList.length == 1 ? '-' : '-->'} ${aliasList.map((e) {
              return e.alias;
            }).toList().join('\n- ')}';

    var taskIds = tp?.idTask ?? bridge.trackPointTaskIdList;
    taskList = taskIds.map((id) => ModelTask.getTask(id)).toList();
    taskList.sort((a, b) => a.sortOrder - b.sortOrder);
    tasksText = taskList.isEmpty
        ? ' ---'
        : taskList
            .map((e) {
              return '- ${e.task}';
            })
            .toList()
            .join('\n');

    var userIds = tp?.idUser ?? bridge.trackPointUserIdList;
    userList = userIds.map((id) => ModelUser.getUser(id)).toList();
    userList.sort((a, b) => a.sortOrder - b.sortOrder);
    usersText = userList.isEmpty
        ? ' ---'
        : userList
            .map((e) {
              return '- ${e.user}';
            })
            .toList()
            .join('\n');

    trackPointNotes = tp?.notes ?? bridge.trackPointUserNotes;
    durationText = timeElapsed(tStart, tEnd, false);
    var addr = tp?.address ?? bridge.currentAddress;
    addressText = addr.isEmpty ? '---' : addr;

    /// calendar
    var calData = (tp?.calendarId ??
            '${bridge.selectedCalendarId};${bridge.lastCalendarEventId}')
        .split(';');
    if (calData.isNotEmpty) {
      calendarId = calData[0];
    }
    if (calData.length > 1) {
      calendarEventId = calData[1];
    }
  }
}
