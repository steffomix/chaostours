import 'package:chaostours/address.dart';
import 'package:chaostours/enum.dart';
import 'package:chaostours/events.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/model/model.dart';
import 'package:chaostours/shared_model/shared.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/event_manager.dart';

/*
class SharedTracker {
  static SharedTracker? _instance;
  SharedTracker._() {
    EventManager.listen<EventOnBackgroundGpsChanged>(onGps);
  }
  factory SharedTracker() => _instance ??= SharedTracker._();
  static SharedModelTracking? activeModel;

  void onGps(EventOnBackgroundGpsChanged event) {
    GPS gps = event.gps;
    SharedModelTracking model = SharedModelTracking(gps);
    SharedModelTracking lastActiveModel = activeModel ?? model;
    activeModel = model;
  }
}
*/
class SharedModelTracking {
  static Logger logger = Logger.logger<SharedModelTracking>();

  GPS gps;
  //
  TrackingStatus status = TrackingStatus.none;
  List<GPS> trackPoints = []; // "lat,lon;lat,lon;..."
  DateTime timeStart = DateTime.now();
  DateTime timeEnd = DateTime.now();
  List<int> idAlias = []; // "id,id,..." needs to be sorted by distance
  List<int> idTask = []; // "id,id,..." needs to be ordered by user
  String notes = '';
  late Address address;

  SharedModelTracking(this.gps) {
    address = Address(gps);
  }

  /// <p><b>TSV columns: </b></p>
  /// 0 TrackingStatus index<br>
  /// 1 gps.lat<br>
  /// 2 gps.lon<br>
  /// 3 timeStart as toIso8601String<br>
  /// 4 timeEnd as above<br>
  /// 5 idAlias separated by ,<br>
  /// 6 idTask separated by ,<br>
  /// 7 notes Uri.encodeFull encoded<br>
  /// 8 lat, lon TrackPoints separated by ; and reduced to four digits<br>
  /// 9 | as line end
  @override
  String toString() {
    List<String> cols = [
      status.index.toString(), // 0
      gps.lat.toString(), // 1
      gps.lon.toString(), // 2
      timeStart.toIso8601String(), // 3
      timeEnd.toIso8601String(), // 4
      idAlias.join(','), // 5
      idTask.join(','), // 6
      encode(notes), // 7
      status == TrackingStatus.moving
          ? trackPoints
              .map((gps) => '${(gps.lat * 10000).round() / 10000},'
                  '${(gps.lon * 10000).round() / 10000}')
              .toList()
              .join(';')
          : '', // 8
      '|' // 9 (secure line end)
    ];
    return cols.join('\t');
  }

  /// <p><b>TSV columns: </b></p>
  /// 0 TrackingStatus index<br>
  /// 1 gps.lat <br>
  /// 2 gps.lon<br>
  /// 3 timeStart as toIso8601String<br>
  /// 4 timeEnd as above<br>
  /// 5 idAlias separated by ,<br>
  /// 6 idTask separated by ,<br>
  /// 7 notes Uri.encodeFull encoded<br>
  /// 8 lat, lon TrackPoints separated by ; and reduced to four digits<br>
  /// | as line end
  static SharedModelTracking toModel(String row) {
    List<String> p = row.split('\t');
    GPS gps = GPS(double.parse(p[1]), double.parse(p[2]));
    SharedModelTracking st = SharedModelTracking(gps);
    st.address = Address(gps);
    st.timeStart = DateTime.parse(p[3]);
    st.timeEnd = DateTime.parse(p[4]);
    st.idAlias = _parseIds(p[5]);
    st.idTask = _parseIds(p[6]);
    st.notes = decode(p[7]);
    st.trackPoints = _parseGps(p[8]);
    return st;
  }

  static List<GPS> _parseGps(String src) {
    List<GPS> gps = [];
    src = src.trim();
    if (src.isEmpty) return gps;
    List<String> latLon;
    for (var coord in src.split(';')) {
      latLon = coord.split(',');
      gps.add(GPS(double.parse(latLon[0]), double.parse(latLon[1])));
    }
    return gps;
  }

  static List<int> _parseIds(String src) {
    List<int> ids = [];
    src = src.trim();
    if (src.isEmpty) return ids;
    for (var id in src.split(',')) {
      ids.add(int.parse(id));
    }
    return ids;
  }
}
