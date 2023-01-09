import 'log.dart';
import 'gps.dart';
import 'package:http/http.dart' as http;
import 'package:sprintf/sprintf.dart' show sprintf;
//
import 'package:chaostours/recource_loader.dart';

///
///<addressparts>
///<house_number>8</house_number>
///<road>Scheffelstraße</road>
///<retail>Engelbosteler Damm</retail>
///<town>Innenstadt</town>
///<suburb>Nordstadt</suburb>
///<city_district>Nord</city_district>
///<city>Hannover</city>
///<county>Region Hannover</county>
///<state>Niedersachsen</state>
///<ISO3166-2-lvl4>DE-NI</ISO3166-2-lvl4>
///<postcode>30167</postcode>
///<country>Deutschland</country>
///<country_code>de</country_code>
///</addressparts>
///
class Address {
  final GPS _gps;
  final DateTime _time = DateTime.now();
  bool _loaded = false;
  String road = '';
  // ignore: non_constant_identifier_names
  String house_number = '';
  String town = '';
  String retail = '';
  String suburb = '';
  // ignore: non_constant_identifier_names
  String city_district = '';
  String city = '';
  String county = '';
  String state = '';
  String postcode = '';

  double get lat => _gps.lat;
  double get lon => _gps.lon;
  GPS get gps => _gps;
  DateTime get time => _time;
  String get asString {
    String addr = '$road $house_number, ';
    addr += town == ''
        ? '$postcode $city $city_district, $retail $suburb'
        : '$postcode $town';
    return addr;
  }

  bool get loaded => _loaded;

  Address(this._gps);

  Future<Address> lookupAddress() async {
    try {
      http.Response response = await RecourceLoader.osmReverseLookup(_gps);
      if (response.statusCode == 200) {
        String body = response.body;
        String pattern = r'<%s>(.*)<\/%s>';
        Map<String, String> tags = {
          'road': '',
          'hous_number': '',
          'town': '',
          'retail': '',
          'suburb': '',
          'city_district': '',
          'city': '',
          'county': '',
          'state': '',
          'postcode': '',
        };
        tags.forEach((String k, String v) {
          RegExp rx = RegExp(sprintf(pattern, [k, k]));
          tags[k] = rx.firstMatch(body)?.group(1) ?? '';
        });

        road = tags['road'] ?? '';
        house_number = tags['house_number'] ?? '';
        town = tags['town'] ?? '';
        retail = tags['retail'] ?? '';
        suburb = tags['suburb'] ?? '';
        city_district = tags['city_district'] ?? '';
        city = tags['city'] ?? '';
        county = tags['county'] ?? '';
        state = tags['state'] ?? '';
        postcode = tags['postcode'] ?? '';
      } else {
        logWarn(
            'lookup address failed with status code: ${response.statusCode}\n'
            '${response.body}');
      }
    } catch (e, stk) {
      // ignore
      logError('Address::lookupAdress', e, stk);
    }
    _loaded = true;
    //logInfo('Address parsed OSM reverse lookup result on GPS #${_gps.id}:\n$asString');
    return this;
  }
}
