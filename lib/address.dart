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
import 'package:chaostours/value_expired.dart';
import 'package:http/http.dart' as http;

///
import 'package:chaostours/database/cache.dart';
import 'package:chaostours/conf/app_user_settings.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/logger.dart';

class Address {
  static Logger logger = Logger.logger<Address>();

  static const expireAfter = Duration(seconds: 3);
  static const _msgOSMFailed = 'OSM Lookup failed';
  static const messageDenyAddressLookup =
      'Address Lookup denied by User Setting';
  final GPS _gps;

  ValueExpired? lastResponse;
  http.Response? _response;

  bool? _permissionGranted;
  bool? get permissionGranted => _permissionGranted;

  OsmLookupConditions? _lookupCondition;
  OsmLookupConditions? _lookupConditionRequired;

  Address(this._gps);

  double get lat => _gps.lat;
  double get lon => _gps.lon;
  GPS get gps => _gps;

  String? _alias;
  String? get alias {
    if (_alias != null) {
      return _alias!;
    }
    String? checkResponse = _checkResponse();
    if (checkResponse != null) {
      return checkResponse;
    }
    try {
      final body = _response!.body;
      var json = jsonDecode(body);
      return _alias = (json['display_name'] ?? _msgOSMFailed);
    } catch (e, stk) {
      _alias = 'Parse OSM Result failed: $e';
      logger.error(_alias, stk);
      return _alias;
    }
  }

  String? _description;
  String? get description {
    if (_description != null) {
      return _description!;
    }
    String? checkResponse = _checkResponse();
    if (checkResponse != null) {
      return checkResponse;
    }
    try {
      final body = _response!.body;
      final json = jsonDecode(body);

      Map<String, dynamic> jsonParts = json['address'] ?? <String, dynamic>{};
      List<String> parts = [];
      for (var key in jsonParts.keys) {
        parts.add('$key: ${jsonParts[key]}');
      }
      parts.add(
          '\nData © OpenStreetMap contributors, ODbL 1.0. www.openstreetmap.org/copyright');
      return _description = parts.join('\n');
    } catch (e, stk) {
      _description = 'Parse OSM Result failed: $e';
      logger.error(_description, stk);
      return _description;
    }
  }

  String? _checkResponse() {
    if (!(_permissionGranted ?? false)) {
      return 'OSM Request permission required: ${_lookupConditionRequired?.name}, given: ${_lookupCondition?.name}';
    }
    if (_response == null) {
      return 'OSM request failed for unknown reason, Response is NULL.';
    }
    if (_response!.statusCode != 200) {
      return 'Response status code is != 200 (actually ${_response?.statusCode ?? 'unknown'})';
    }
    return null;
  }

  // OpenStreeMap limit of one request per second
  Future<void> requestLimit() async {
    while (await Cache.addressLastLookup.load<int>(0) + 1000 >
        DateTime.now().millisecondsSinceEpoch) {
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }

  Future<Address> lookup(OsmLookupConditions condition,
      {bool saveToCache = false}) async {
    _lookupCondition = condition;
    if (_response != null) {
      return this;
    }
    _lookupConditionRequired = await Cache.appSettingOsmLookupCondition
        .load<OsmLookupConditions>(OsmLookupConditions.never);

    if (await condition.allowLookup()) {
      _permissionGranted = true;
      final url = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'lat': gps.lat.toString(),
        'lon': gps.lon.toString(),
        'format': 'json'
      });

      await requestLimit();

      await Cache.addressLastLookup
          .save<int>(DateTime.now().millisecondsSinceEpoch);
      _response = await http.get(url);
      if (saveToCache) {
        await Cache.backgroundAddress.save<String>(alias ?? '');
      }
    } else {
      _permissionGranted = false;
      _alias = messageDenyAddressLookup;
      _description = '';
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