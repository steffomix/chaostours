/*
Copyright 2023 Stefan Brinkmann <st.brinkmann@gmail.com>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

import 'dart:convert';
import 'package:http/http.dart' as http;

///
import 'package:chaostours/database/cache.dart';
import 'package:chaostours/conf/app_user_settings.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/logger.dart';

enum CheckResponseCodes {
  ok,
  permissionDenied,
  badStatusCode,
  unknownError;
}

class Address {
  static Logger logger = Logger.logger<Address>();

  final GPS _gps;

  http.Response? _response;
  static http.Response? _lastResponse;

  bool _permissionGranted = false;
  bool? get permissionGranted => _permissionGranted;

  CheckResponseCodes _responseCheck = CheckResponseCodes.ok;

  Address(this._gps);

  double get lat => _gps.lat;
  double get lon => _gps.lon;
  GPS get gps => _gps;

  String? _location;
  String get address => _location ??= _parseLocation();

  String _parseLocation() {
    try {
      final body = _response?.body;
      var json = jsonDecode(body ?? '{}');
      return (json['display_name'] ?? '');
    } catch (e, stk) {
      String msg = 'Parse OSM Result failed: $e';
      logger.error(msg, stk);
      return msg;
    }
  }

  String? _description;
  String get addressDetails => _description ??= _parseDescription();

  String _parseDescription() {
    try {
      final body = _response?.body;
      final json = jsonDecode(body ?? '{}');

      Map<String, dynamic> addressParts =
          json['address'] ?? <String, dynamic>{};
      List<String> parts = [];
      if (addressParts.keys.isEmpty) {
        return '';
      }
      for (var key in addressParts.keys) {
        parts.add('$key: ${addressParts[key]}');
      }
      if (_responseCheck != CheckResponseCodes.ok) {
        parts.add('Old (outdated Address) due to ${_responseCheck.name}');
      }
      parts.add('\n© OpenStreetMap www.openstreetmap.org/copyright');
      return _description = parts.join('\n');
    } catch (e, stk) {
      _description = 'OSM Address parse Error: $e';
      logger.error(_description, stk);
      return _description!;
    }
  }

  CheckResponseCodes _checkResponse(http.Response? response) {
    if (!(_permissionGranted)) {
      return CheckResponseCodes.permissionDenied;
      //return 'OSM Request permission required: ${_lookupConditionRequired?.name}, given: ${_lookupCondition?.name}';
    } else if (response?.statusCode != 200) {
      return CheckResponseCodes.badStatusCode;
      //return 'Response status code is != 200 (actually ${_response?.statusCode ?? 'unknown'})';
    } else if (response == null) {
      return CheckResponseCodes.unknownError;
    } else {
      return CheckResponseCodes.ok;
    }
  }

  // OpenStreeMap limit of one request per second
  Future<void> requestLimit() async {
    while (await Cache.addressTimeLastLookup.load<int>(0) + 1000 >
        DateTime.now().millisecondsSinceEpoch) {
      await Future.delayed(const Duration(milliseconds: 200));
    }
    await Cache.addressTimeLastLookup
        .save<int>(DateTime.now().millisecondsSinceEpoch);
  }

  Future<Address> lookup(OsmLookupConditions condition,
      {bool saveToCache = false}) async {
    if (_response != null) {
      return this;
    }
    _permissionGranted = await condition.allowLookup();
    if (!_permissionGranted) {
      return this;
    }

    _permissionGranted = true;

    final url = Uri.https('nominatim.openstreetmap.org', '/reverse', {
      'lat': gps.lat.toString(),
      'lon': gps.lon.toString(),
      'format': 'json'
    });

    await requestLimit();

    var response = await http.get(url);
    _responseCheck = _checkResponse(response);
    if (_responseCheck != CheckResponseCodes.ok) {
      _response = _lastResponse;
      return this;
    }
    _lastResponse = _response = response;
    if (saveToCache) {
      await Cache.addressMostRecent.save<String>(address);
      await Cache.addressFullMostRecent.save<String>(addressDetails);
    }
    return this;
  }
}


/*

/// example 1
{
    "place_id": 114611343,
    "licence": "Data © OpenStreetMap contributors, ODbL 1.0. http://osm.org/copyright",
    "osm_type": "node",
    "osm_id": 8068787031,
    "lat": "48.793522",
    "lon": "2.439843",
    "category": "place",
    "type": "house",
    "place_rank": 30,
    "importance": 9.99999999995449e-06,
    "addresstype": "place",
    "name": "",
    "display_name": "36, Rue de Bazeilles, Liberté - Vert-de-Maisons, Maisons-Alfort, Nogent-sur-Marne, Val-de-Marne, Ile-de-France, Metropolitanes Frankreich, 94700, Frankreich",
    "address": {
        "house_number": "36",
        "road": "Rue de Bazeilles",
        "suburb": "Liberté - Vert-de-Maisons",
        "town": "Maisons-Alfort",
        "municipality": "Nogent-sur-Marne",
        "county": "Val-de-Marne",
        "ISO3166-2-lvl6": "FR-94",
        "state": "Ile-de-France",
        "ISO3166-2-lvl4": "FR-IDF",
        "region": "Metropolitanes Frankreich",
        "postcode": "94700",
        "country": "Frankreich",
        "country_code": "fr"
    },
    "boundingbox": [
        "48.7934720",
        "48.7935720",
        "2.4397930",
        "2.4398930"
    ]
}

/// example 2
{
    "place_id": 4357024,
    "licence": "Data © OpenStreetMap contributors, ODbL 1.0. http://osm.org/copyright",
    "osm_type": "way",
    "osm_id": 172467860,
    "lat": "38.91823226548721",
    "lon": "-77.17556034259437",
    "class": "highway",
    "type": "path",
    "place_rank": 27,
    "importance": 0.07500999999999991,
    "addresstype": "road",
    "name": "Pimmit Run Trail (Upstream)",
    "display_name": "Pimmit Run Trail (Upstream), Devon Park, Foxhall, McLean, Fairfax County, Virginia, 22101, Vereinigte Staaten von Amerika",
    "address": {
        "road": "Pimmit Run Trail (Upstream)",
        "neighbourhood": "Devon Park",
        "hamlet": "Foxhall",
        "town": "McLean",
        "county": "Fairfax County",
        "state": "Virginia",
        "ISO3166-2-lvl4": "US-VA",
        "postcode": "22101",
        "country": "Vereinigte Staaten von Amerika",
        "country_code": "us"
    },
    "boundingbox": [
        "38.9158134",
        "38.9201357",
        "-77.1778191",
        "-77.1745489"
    ]
}

/// example 3
{
    "place_id": 4296735,
    "licence": "Data © OpenStreetMap contributors, ODbL 1.0. http://osm.org/copyright",
    "osm_type": "way",
    "osm_id": 238241022,
    "lat": "38.897699700000004",
    "lon": "-77.03655315",
    "class": "office",
    "type": "government",
    "place_rank": 30,
    "importance": 0.6347211541681101,
    "addresstype": "office",
    "name": "Weißes Haus",
    "display_name": "Weißes Haus, 1600, Pennsylvania Avenue Northwest, Ward 2, Washington, District of Columbia, 20500, Vereinigte Staaten von Amerika",
    "address": {
        "office": "Weißes Haus",
        "house_number": "1600",
        "road": "Pennsylvania Avenue Northwest",
        "borough": "Ward 2",
        "city": "Washington",
        "state": "District of Columbia",
        "ISO3166-2-lvl4": "US-DC",
        "postcode": "20500",
        "country": "Vereinigte Staaten von Amerika",
        "country_code": "us"
    },
    "boundingbox": [
        "38.8974908",
        "38.8979110",
        "-77.0368537",
        "-77.0362519"
    ]
}


*/