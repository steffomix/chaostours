import 'package:http/http.dart' as http;
import 'package:sprintf/sprintf.dart';

const _url = 'nominatim.openstreetmap.org';
const _page = '/reverse';

class Address {
  final DateTime date = DateTime.now();
  double lat;
  double lon;
  String street;
  String house;
  String code;
  String town;
  Address(this.lat, this.lon, this.street, this.house, this.code, this.town);

  Address.empty()
      : lat = 0,
        lon = 0,
        street = '',
        house = '',
        code = '',
        town = '';

  String address() {
    return '$street $house, $code $town';
  }
}

class GeoCoding {
  // stores last lookups
  static final _lookups = <Address>[Address.empty()];
  static Address _lastLookup = Address.empty();

  // parses Address from openstreetmap response
  void _parseAddress(String res, double lat, double lon) {
    String pattern = r'<%s>(.*)<\/%s>';
    String streetTag = 'road';
    String houseTag = 'house_number';
    String townTag = 'town';
    String postCodeTag = 'postcode';
    RegExp street = RegExp(sprintf(pattern, [streetTag, streetTag]));
    RegExp house = RegExp(sprintf(pattern, [houseTag, houseTag]));
    RegExp town = RegExp(sprintf(pattern, [townTag, townTag]));
    RegExp postCode = RegExp(sprintf(pattern, [postCodeTag, postCodeTag]));
    _lastLookup = Address(
        lat,
        lon,
        street.firstMatch(res)?.group(1) ?? '',
        house.firstMatch(res)?.group(1) ?? '',
        postCode.firstMatch(res)?.group(1) ?? '',
        town.firstMatch(res)?.group(1) ?? '');

    _lookups.add(_lastLookup);
  }

  startTracking(Function f) {
    f(Address.empty());
  }

  ///
  /// return oldest address
  Address get address {
    if (_lookups.isNotEmpty) {
      Address addr = _lookups.last;
      _lookups.removeLast();
      return addr;
    }
    return Address.empty();
  }

  Address get lastAddress {
    return _lastLookup;
  }

  // lookup geo location
  void lookup(double lat, double lon) async {
    var params = {'lat': lat.toString(), 'lon': lon.toString()};
    var url = Uri.https(_url, _page, params);
    var response = await http.get(url);
    if (response.statusCode == 200) {
      _parseAddress(response.body, lat, lon);
    }
  }
}
