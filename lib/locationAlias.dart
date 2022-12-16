import 'logger.dart' show log;
import 'config.dart';
import 'package:geolocator/geolocator.dart';
import 'recourceLoader.dart';

class LocationAlias {
  static List<Alias>? _loadedAliasList;
  static Future<List<Alias>> loadeAliasList() async {
    if (_loadedAliasList != null) {
      return Future<List<Alias>>.value(_loadedAliasList);
    }
    String tsv = await RecourceLoader.locationAlias();
    List<Alias> list = [];
    List<String> rows = tsv.split('\n');
    if (rows.length > 1) {
      // remove description header
      rows.removeAt(0);
      for (String r in rows) {
        Alias? alias = Alias.parseTsv(r);
        if (alias != null) list.add(alias);
      }
    }

    _loadedAliasList = list;
    return Future<List<Alias>>.value(list);
  }

  static Future<List<Alias>> findAlias(double lat, double lon) async {
    List<Alias> list = await loadeAliasList();
    List<Alias> l = [];
    for (var a in list) {
      if (Geolocator.distanceBetween(lat, lon, a.lat, a.lon) <=
          AppConfig.distanceTreshold) {
        l.add(a);
        log('found alias ${a.address} (${a.alias})');
      }
    }
    return Future<List<Alias>>.value(list);
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
    try {
      int rId = int.parse(list[0]);
      double rLat = double.parse(list[1]);
      double rLon = double.parse(list[2]);
      String rAlias = list[3];
      Alias alias = Alias(rId, rAlias, rLat, rLon);
      try {
        alias.status = l >= 5 ? int.parse(list[4]) : 0;
      } catch (e) {
        log('LocationAlias::parseStatus: $e');
      }
      try {
        alias.lastVisited = l >= 6 ? DateTime.parse(list[5]) : DateTime.now();
      } catch (e) {
        log('LocationAlias::parse DateTime lastVisited: $e');
        alias.lastVisited = DateTime.now();
      }
      try {
        alias.timesVisited = l >= 7 ? int.parse(list[6]) : 0;
      } catch (e) {
        log('LocationAlias::parse DateTime timesVisited $e');
        alias.timesVisited = 0;
      }

      alias.address = l >= 8 ? list[7] : '';
      alias.notes = l >= 9 ? list[8] : '';
      log('added alias ${alias.address}');
      return alias;
    } catch (e) {
      log('$e');
    }
    return null;
  }

  String get tsv {
    return '$lat\t$lon\t$alias\t$status\t${lastVisited.toString()}\t$timesVisited\t"$address"\t"$notes"';
  }
}
