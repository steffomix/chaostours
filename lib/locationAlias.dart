import 'logger.dart' show log;
import 'package:flutter/services.dart' show rootBundle;

class LocationAlias {
  static const double radius = 0.00145; // 100m alias radius

  final double lat;
  final double lon;

  final List<Alias> _alias = [];

  final _AliasLoader _list = _AliasLoader();

  Alias get alias => _alias.isNotEmpty ? _alias.first : Alias('', 0, 0);

  List<Alias> get allAlias => _alias;

  LocationAlias(this.lat, this.lon) {
    var r = radius;
    _list.walk((a) {
      if (lat - r > a.lat &&
          lat + r < a.lat &&
          lon - r > a.lon &&
          lon + r < a.lon) _alias.add(a);
    });
  }
}

class _AliasLoader {
  final List<Alias> _list = [];
  static final _aliasList = _AliasLoader._init();

  factory _AliasLoader() => _aliasList;

  walk(Function(Alias) cb) {
    for (var i = 0; i < _list.length; i++) {
      cb(_list[i]);
    }
  }

  _AliasLoader._init() {
    rootBundle.loadString('assets/locationAlias.tsv').then((aliasList) {
      List rows = aliasList.split('\n');
      if (rows.isEmpty) return;
      for (String r in rows) {
        r = r.trim();
        List cols = r.split(','); // split with tab
        if (cols.length != 3) {
          log('AliasList entry damaged: $r');
        } else {
          try {
            String name = cols[0];
            double lat = double.parse(cols[1]);
            double lon = double.parse(cols[2]);
            Alias alias = Alias(name, lat, lon);
            log('Add alias: $r');
            _list.add(alias);
          } catch (e) {
            log('create AliasList entry failed: $e');
          }
        }
      }
    }).onError((error, stackTrace) =>
        log('Loading AliasList failed: ${error.toString()}'));
  }
}

class Alias {
  final String name;
  final double lat;
  final double lon;

  bool get isEmpty {
    return name == '' && lat == 0 && lon == 0;
  }

  Alias(this.name, this.lat, this.lon);
}
