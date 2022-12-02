import 'logger.dart';
import 'gps.dart';
import 'package:http/http.dart' as http;
import 'package:sprintf/sprintf.dart' show sprintf;

class Address {
  final GPS _gps;
  final DateTime _time = DateTime.now();
  final String street = '';
  final String house = '';
  final String code = '';
  final String town = '';

  double get lat {
    return _gps.lat;
  }

  double get lon {
    return _gps.lon;
  }

  DateTime get time {
    return time;
  }

  Address(this._gps) {
    _lookupAddress();
  }

  Address.empty() : _gps = GPS();

  String get asString {
    return '$street $house, $code $town';
  }

  void _lookupAddress() async {
    var url = Uri.https('nominatim.openstreetmap.org', '/reverse',
        {'lat': lat.toString(), 'lon': lon.toString()});
    http.get(url).then((response) {
      if (response.statusCode == 200) {
        String body = response.body;
        String pattern = r'<%s>(.*)<\/%s>';
        String streetTag = 'road';
        String houseTag = 'house_number';
        String townTag = 'town';
        String postCodeTag = 'postcode';
        RegExp street = RegExp(sprintf(pattern, [streetTag, streetTag]));
        RegExp house = RegExp(sprintf(pattern, [houseTag, houseTag]));
        RegExp town = RegExp(sprintf(pattern, [townTag, townTag]));
        RegExp postCode = RegExp(sprintf(pattern, [postCodeTag, postCodeTag]));

        street.firstMatch(body)?.group(1) ?? '';
        house.firstMatch(body)?.group(1) ?? '';
        postCode.firstMatch(body)?.group(1) ?? '';
        town.firstMatch(body)?.group(1) ?? '';
      }
    }).onError((error, stackTrace) {
      severe('lookup address failed: ${error.toString()}');
    });
  }
}
