import 'logger.dart';
import 'geoTracking.dart' show GeoCoding;
import 'dart:math';
import 'package:geolocator/geolocator.dart';

import 'package:sprintf/sprintf.dart' show sprintf;
import 'package:http/http.dart' as http;

class GPS {
  static const _url = 'nominatim.openstreetmap.org';
  static const _page = '/reverse';

  final DateTime time = DateTime.now();
  double lat = 0;
  double lon = 0;
  Address _address = Address.empty();

  final Function(GPS) _callback;

  GPS(this._callback) {
    //_gps();
    _testGps();
  }

  Address get address {
    return _address;
  }

  set address(Address adr) {
    _address = adr;
    log(_address.asString);
    _callback(this);
  }

  static final double _lat = 52.3367;
  static final double _lon = 9.21645353535;
  static double _latMod = 0;
  static double _lonMod = 0;

  void _testGps() {
    Future.delayed(const Duration(seconds: 3), () {
      if (Random().nextInt(10) > 6) {
        GPS._latMod = Random().nextDouble();
        GPS._lonMod = Random().nextDouble();
      }
      lat = GPS._lat + GPS._latMod;
      lon = GPS._lon + GPS._lonMod;

      GeoCoding(this);
    });
  }

  void _gps() async {
    Position p = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);

    lat = p.latitude;
    lon = p.longitude;
  }

  // lookup geo location on openstreetmap.org
  void _lookupGPS() async {
    var params = {'lat': lat.toString(), 'lon': lon.toString()};
    var url = Uri.https(_url, _page, params);
    var response = await http.get(url);
    if (response.statusCode == 200) {
      _parseAddress(response.body);
    }
  }

  void _parseAddress(String res) {
    String pattern = r'<%s>(.*)<\/%s>';
    String streetTag = 'road';
    String houseTag = 'house_number';
    String townTag = 'town';
    String postCodeTag = 'postcode';
    RegExp street = RegExp(sprintf(pattern, [streetTag, streetTag]));
    RegExp house = RegExp(sprintf(pattern, [houseTag, houseTag]));
    RegExp town = RegExp(sprintf(pattern, [townTag, townTag]));
    RegExp postCode = RegExp(sprintf(pattern, [postCodeTag, postCodeTag]));
    Address address = Address(
        lat,
        lon,
        street.firstMatch(res)?.group(1) ?? '',
        house.firstMatch(res)?.group(1) ?? '',
        postCode.firstMatch(res)?.group(1) ?? '',
        town.firstMatch(res)?.group(1) ?? '');
    address = address;
  }
}

class Address {
  final DateTime time = DateTime.now();
  final double lat;
  final double lon;
  final String street;
  final String house;
  final String code;
  final String town;
  Address(this.lat, this.lon, this.street, this.house, this.code, this.town);

  Address.empty()
      : lat = 0,
        lon = 0,
        street = '',
        house = '',
        code = '',
        town = '';

  String get asString {
    return '$street $house, $code $town';
  }
}

class GeoCoding {
  static const _url = 'nominatim.openstreetmap.org';
  static const _page = '/reverse';

  GeoCoding(GPS gps) {
    log('Lookup ${gps.lat}, ${gps.lon}');
    lookup(gps);
  }

  // lookup geo location on openstreetmap.org
  void lookup(GPS gps) async {
    var params = {'lat': gps.lat.toString(), 'lon': gps.lon.toString()};
    var url = Uri.https(_url, _page, params);
    var response = await http.get(url);
    if (response.statusCode == 200) {
      _parseAddress(response.body, gps);
    }
  }

  // parses Address from openstreetmap response
  void _parseAddress(String res, GPS gps) {
    String pattern = r'<%s>(.*)<\/%s>';
    String streetTag = 'road';
    String houseTag = 'house_number';
    String townTag = 'town';
    String postCodeTag = 'postcode';
    RegExp street = RegExp(sprintf(pattern, [streetTag, streetTag]));
    RegExp house = RegExp(sprintf(pattern, [houseTag, houseTag]));
    RegExp town = RegExp(sprintf(pattern, [townTag, townTag]));
    RegExp postCode = RegExp(sprintf(pattern, [postCodeTag, postCodeTag]));
    Address address = Address(
        gps.lat,
        gps.lon,
        street.firstMatch(res)?.group(1) ?? '',
        house.firstMatch(res)?.group(1) ?? '',
        postCode.firstMatch(res)?.group(1) ?? '',
        town.firstMatch(res)?.group(1) ?? '');
    gps.address = address;
  }
}
