import 'logger.dart' show log;
import 'config.dart';
import 'package:geolocator/geolocator.dart';
import 'recourceLoader.dart';

class LocationAlias {
  static final List<Alias> _loadedList = [];

  static bool _loaded = _loadAliasList();
  static bool get loaded => _loaded;

  static bool _loadAliasList() {
    RecourceLoader.locationAlias().then((String aliasList) {
      List<String> rows = aliasList.split('\n');
      if (rows.isEmpty) return;
      for (String r in rows) {
        Alias? alias = Alias.parseTsv(r);
        if (alias != null) _loadedList.add(alias);
      }
      _loaded = true;
    }).onError((error, stackTrace) =>
        log('Loading AliasList failed: ${error.toString()}'));
    return false;
  }

  static List<Alias> alias(double lat, double lon, List<Alias> list) {
    for (var a in _loadedList) {
      if (Geolocator.distanceBetween(lat, lon, a.lat, a.lon) <=
          AppConfig.distanceTreshold) {
        list.add(a);
        log('found alias ${a.address}');
      }
    }

    return list;
  }
}

// Latitude	Longitude	Alias	Status	Last visited	Times visted	Address
class Alias {
  final int _id;
  final String alias;
  final double lat;
  final double lon;
  int status = 0;
  DateTime lastVisited = DateTime.now();
  int timesVisited = 0;
  String address = '';
  String notes = '';

  Alias(this._id, this.alias, this.lat, this.lon);

  static Alias? parseTsv(String tsv) {
    List<String> list = tsv.split('\t');
    int l = list.length;
    if (l < 4) return null;
    int rId = int.parse(list[0]);
    double rLat = double.parse(list[1]);
    double rLon = double.parse(list[2]);
    String rAlias = list[3];
    Alias alias = Alias(rId, rAlias, rLat, rLon);
    alias.lastVisited = l >= 5 ? DateTime.parse(list[4]) : DateTime.now();
    alias.timesVisited = l >= 6 ? int.parse(list[5]) : 0;
    alias.address = l >= 7 ? list[6] : '';
    alias.notes = l >= 8 ? list[7] : '';
    log('added alias ${alias.address}');
    return alias;
  }

  String get tsv {
    return '$lat\t$lon\t$alias\t$status\t${lastVisited.toIso8601String()}\t$timesVisited\t"$address"\t"$notes"';
  }
}
