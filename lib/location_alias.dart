import 'log.dart';
import 'config.dart';
import 'package:geolocator/geolocator.dart';
import 'recource_loader.dart';
import 'package:chaostours/enum.dart';

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
    List<Alias> found = [];
    for (var a in list) {
      double dist = Geolocator.distanceBetween(lat, lon, a.lat, a.lon);
      if (dist <= AppConfig.distanceTreshold) {
        a.trackPointDistance = dist;
        found.add(a);
        logInfo(
            'LocationAlias::findAlias found alias with distance ${dist.round()}meter\n ${a.address} (${a.alias})');
      }
    }
    found.sort((Alias a, Alias b) => a.compareTo(b));
    return Future<List<Alias>>.value(found);
  }
}

// Latitude	Longitude	Alias	Status	Last visited	Times visted	Address
class Alias implements Comparable<Alias> {
  final int _id;
  //
  String _alias;
  String get alias => _alias;
  set alias(String a) => _alias = _purifyString(a);
  //
  double lat;
  double lon;
  AliasStatus status = AliasStatus.public;
  DateTime lastVisited = DateTime.now();
  int timesVisited = 0;
  //
  String _address = '';
  String get address => _address;
  set address(String str) => _address = _purifyString(str);
  //
  String _notes = '';
  String get notes => _notes;
  set notes(String str) => _notes = _purifyString(str);
  //
  double trackPointDistance = 0;
  //
  static const String _space = '    ';

  static String _purifyString(String str) {
    return str
        .replaceAll('\n', '')
        .replaceAll('\r', '')
        .replaceAll('\t', _space);
  }

  Alias(this._id, this._alias, this.lat, this.lon);

  static Alias? parseTsv(String tsv) {
    List<String> list = tsv.split('\t');
    int l = list.length;
    if (l < 4) {
      logWarn('Alias::parseTsv: invalit tsv line:\n$tsv');
      return null;
    }
    try {
      int rId = int.parse(list[0]);
      double rLat = double.parse(list[1]);
      double rLon = double.parse(list[2]);
      String rAlias = _purifyString(list[3]);
      Alias alias = Alias(rId, rAlias, rLat, rLon);
      alias.notes = l >= 5 ? list[4] : '';
      try {
        alias.status = AliasStatus.byValue(l >= 6 ? int.parse(list[5]) : 0);
      } catch (e) {
        logWarn('LocationAlias::parseStatus', e);
      }
      try {
        alias.lastVisited = l >= 7 ? DateTime.parse(list[6]) : DateTime.now();
      } catch (e) {
        // logWarn('LocationAlias::parse DateTime lastVisited', e);
        alias.lastVisited = DateTime.now();
      }
      try {
        alias.timesVisited = l >= 8 ? int.parse(list[7]) : 0;
      } catch (e) {
        logWarn('LocationAlias::parse DateTime timesVisited', e);
        alias.timesVisited = 0;
      }

      //logInfo('added alias ${alias.address}');
      return alias;
    } catch (e) {
      log('$e');
    }
    return null;
  }

  String get tsv {
    try {
      List<String> parts = [
        _id.toString(),
        lat.toString(),
        lon.toString(),
        alias,
        status.toString(),
        lastVisited.toIso8601String(),
        timesVisited.toString(),
        address,
        notes
      ];
      return parts.join('\t');
    } catch (e) {
      logError('Alias::tsv', e);
    }
    return '';
  }

  @override
  int compareTo(Alias other) {
    int compare = trackPointDistance.round() - other.trackPointDistance.round();
    return compare;
  }
}
