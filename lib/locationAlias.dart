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

  static List<Alias> alias(double lat, double lon) {
    List<Alias> list = [];
    for (var a in _loadedList) {
      if (Geolocator.distanceBetween(lat, lon, a.lat, a.lon) <=
          AppConfig.distanceTreshold) list.add(a);
    }

    return list;
  }
}

// Latitude	Longitude	Alias	Status	Last visited	Times visted	Address
class Alias {
  final String alias;
  final double lat;
  final double lon;
  int status = 0;
  DateTime lastVisited = DateTime.now();
  int timesVisited = 0;
  String address = '';

  Alias(this.alias, this.lat, this.lon);

  static Alias? parseTsv(String tsv) {
    List<String> list = tsv.split('\t');
    int l = list.length;
    if (l < 3) return null;
    double _lat = l >= 1 ? double.parse(list[0]) : 0;
    double _lon = l >= 2 ? double.parse(list[1]) : 0;
    String _alias = l >= 3 ? list[2] : '';
    Alias alias = Alias(_alias, _lat, _lon);
    alias.lastVisited = l >= 4 ? DateTime.parse(list[3]) : DateTime.now();
    alias.timesVisited = l >= 5 ? int.parse(list[4]) : 0;
    alias.address = l >= 6 ? list[5] : '';

    return alias;
  }

  String get tsv {
    return '$lat\t$lon\t$alias\t$status\t${lastVisited.toIso8601String()}\t$timesVisited\t"$address"';
  }
}
