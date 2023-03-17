import 'gps.dart';
import 'package:http/http.dart' as http;
import 'package:sprintf/sprintf.dart' show sprintf;
//
import 'package:chaostours/app_loader.dart';
import 'package:chaostours/logger.dart';

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
///
///
enum OsmTags {
  road,
  // ignore: constant_identifier_names
  house_number,
  town,
  retail,
  suburb,
  // ignore: constant_identifier_names
  city_district,
  city,
  county,
  state,
  postcode
}

class Address {
  static Logger logger = Logger.logger<Address>();
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

  @override
  String toString() {
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
      http.Response response = await AppLoader.osmReverseLookup(_gps);
      if (response.statusCode == 200) {
        String body = response.body;
        logger.log(body);
        String pattern = r'<%s>(.*)<\/%s>';
        Map<OsmTags, String> tags = {
          OsmTags.road: '',
          OsmTags.house_number: '',
          OsmTags.town: '',
          OsmTags.retail: '',
          OsmTags.suburb: '',
          OsmTags.city_district: '',
          OsmTags.city: '',
          OsmTags.county: '',
          OsmTags.state: '',
          OsmTags.postcode: '',
        };
        tags = tags.map((OsmTags key, String value) {
          RegExp rx = RegExp(sprintf(pattern, [key.name, key.name]));
          String res = rx.firstMatch(body)?.group(1) ?? '';
          return MapEntry(key, res);
        });
        road = tags[OsmTags.road] ?? '';
        house_number = tags[OsmTags.house_number] ?? '';
        town = tags[OsmTags.town] ?? '';
        retail = tags[OsmTags.retail] ?? '';
        suburb = tags[OsmTags.suburb] ?? '';
        city_district = tags[OsmTags.city_district] ?? '';
        city = tags[OsmTags.city] ?? '';
        county = tags[OsmTags.county] ?? '';
        state = tags[OsmTags.state] ?? '';
        postcode = tags[OsmTags.postcode] ?? '';
      } else {
        logger.warn(
            'lookup address failed with status code: ${response.statusCode}\n'
            '${response.body}');
      }
    } catch (e, stk) {
      // ignore
      logger.error('lookupAdress failed  $e', stk);
    }
    logger.log('Lookup Address: ${toString()}');
    _loaded = true;
    //logInfo('Address parsed OSM reverse lookup result on GPS #${_gps.id}:\n$asString');
    return this;
  }
}
