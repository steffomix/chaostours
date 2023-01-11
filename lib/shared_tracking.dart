import 'package:chaostours/address.dart';
import 'package:chaostours/enum.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/model.dart';
import 'package:chaostours/shared.dart';

class SharedTracking {
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

  SharedTracking(this.gps) {
    address = Address(gps);
  }

  @override
  String toString() {
    List<String> cols = [
      //_id.toString(), // 0
      //deleted.toString(), // 1
      status.index.toString(), // 2
      gps.lat.toString(), // 3
      gps.lon.toString(), // 4
      timeStart.toIso8601String(), // 5
      timeEnd.toIso8601String(), // 6
      status == TrackingStatus.moving
          ? trackPoints
              .map((gps) => '${(gps.lat * 10000).round() / 10000},'
                  '${(gps.lon * 10000).round() / 10000}')
              .toList()
              .join(';')
          : '', //list.join(';'), // 7
      idAlias.join(','), // 8
      idTask.join(','), // 9
      encode(notes) // 10
    ];
    return cols.join('\t');
  }

  /// 0: gps lat,lon
  /// 1: timeStart
  /// 2: timeEnd
  /// 3: trackPoints [lat,lon;...]
  /// 4: tasks [id, ...]
  /// 5: notes
  static SharedTracking toModel(String row) {
    List<String> p = row.split('\t');
    List<String> latLon = p[0].split(',');
    GPS gps = GPS(double.parse(latLon[0]), double.parse(latLon[1]));
    SharedTracking st = SharedTracking(gps);
    st.address = Address(gps);
    st.timeStart = DateTime.parse(p[1]);
    st.timeEnd = DateTime.parse(p[2]);
    st.trackPoints = _parseGps(p[3]);
    st.idAlias = _parseIds(p[4]);
    st.notes = decode(p[5]);
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
