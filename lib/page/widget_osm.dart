import 'package:chaostours/model/model_alias.dart';
import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';

///
import 'package:chaostours/logger.dart';
import 'package:chaostours/widget/widgets.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/address.dart' as addr;

///
class WidgetOsm extends StatefulWidget {
  const WidgetOsm({super.key});

  @override
  State<WidgetOsm> createState() => _WidgetOsm();
}

class _WidgetOsm extends State<WidgetOsm> {
  static final Logger logger = Logger.logger<WidgetOsm>();

  GPS _gps = GPS(0, 0);
  String _address = '';
  int _id = 0;

  @override
  void initState() {
    GPS.gps().then(((gps) {
      _gps = gps;
      //updateController();
    }));
    super.initState();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  late MapController controller;

  Widget osm(context) {
    return OSMFlutter(
      androidHotReloadSupport: true,
      isPicker: true,
      controller: controller,
      initZoom: 12,
      minZoomLevel: 8,
      maxZoomLevel: 19,
      stepZoom: 1.0,
    );
  }

  Widget infoBox(context) {
    var boxContent = ListTile(
      leading: IconButton(
          icon: const Icon(
              color: Colors.amber, size: 40, Icons.location_searching),
          onPressed: () {
            controller.getCurrentPositionAdvancedPositionPicker().then((loc) {
              _gps = GPS(loc.latitude, loc.longitude);
              controller
                  .goToLocation(
                      GeoPoint(latitude: _gps.lat, longitude: _gps.lon))
                  .then((_) {
                addr.Address(_gps).lookupAddress().then((address) {
                  _address = address.toString();
                  setState(() {});
                }).onError((error, stackTrace) {
                  logger.error(error.toString(), stackTrace);
                });
              });
            }).onError((error, stackTrace) {
              logger.error(error.toString(), stackTrace);
            });
          }),
      title: Text(_address),
      subtitle: Text('GPS: $_gps'),
    );

    return SizedBox(
        height: 120,
        width: 1000,
        child: Container(
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: Colors.white70),
            child: boxContent));
  }

  BottomNavigationBar editNavBar(context) {
    return BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.cancel), label: 'Abbruch'),
          BottomNavigationBarItem(
              icon: Icon(Icons.home), label: 'Meine Position'),
          BottomNavigationBarItem(icon: Icon(Icons.done), label: 'OK')
        ],
        onTap: (int id) async {
          switch (id) {
            case 0:
              Navigator.pushNamed(context, AppRoutes.editAlias.route,
                  arguments: _id);
              break;
            case 1:
              GPS.gps().then(((gps) {
                _gps = gps;
                controller.goToLocation(
                    GeoPoint(latitude: _gps.lat, longitude: _gps.lon));
              }));
              break;
            case 2:
              controller.getCurrentPositionAdvancedPositionPicker().then((pos) {
                var alias = ModelAlias.getAlias(_id);
                alias.lat = pos.latitude;
                alias.lon = pos.longitude;
                addr.Address(GPS(alias.lat, alias.lon))
                    .lookupAddress()
                    .then((adr) {
                  alias.alias = adr.toString();
                  ModelAlias.update();
                  Navigator.pushNamed(context, AppRoutes.editAlias.route,
                      arguments: _id);
                });
              });
              break;
            default:
            // do nothing
          }
        });
  }

  BottomNavigationBar createNavBar(context) {
    return BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.cancel), label: 'Abbruch'),
          BottomNavigationBarItem(
              icon: Icon(Icons.home), label: 'Meine Position'),
          BottomNavigationBarItem(icon: Icon(Icons.done), label: 'OK')
        ],
        onTap: (int id) async {
          switch (id) {
            case 0:
              Navigator.pushNamed(context, AppRoutes.editAlias.route,
                  arguments: 0);
              break;
            case 1:
              GPS.gps().then(((gps) {
                _gps = gps;
                controller.goToLocation(
                    GeoPoint(latitude: _gps.lat, longitude: _gps.lon));
              }));
              break;
            case 2:
              controller.getCurrentPositionAdvancedPositionPicker().then((pos) {
                var alias = ModelAlias(
                    lat: pos.latitude,
                    lon: pos.longitude,
                    alias: '',
                    lastVisited: DateTime.now());

                ModelAlias.insert(alias);
                _id = alias.id;
                Navigator.pushNamed(context, AppRoutes.editAlias.route,
                    arguments: alias.id);
              });
              break;
            default:
            // do nothing
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    try {
      _id = ModalRoute.of(context)!.settings.arguments as int;
      if (_id > 0) {
        var alias = ModelAlias.getAlias(_id);
        _gps = GPS(alias.lat, alias.lon);
        if (_address.isEmpty) {
          _address = alias.alias;
        }
        controller = MapController(
            initMapWithUserPosition: false,
            initPosition: GeoPoint(latitude: _gps.lat, longitude: _gps.lon));
      } else {
        controller = MapController(initMapWithUserPosition: true);
      }
    } catch (e) {
      controller = MapController(initMapWithUserPosition: true);
      logger.warn('no id found in ModalRoute');
    }

    return AppWidgets.scaffold(context,
        body: Stack(children: [
          osm(context),
          infoBox(context),
        ]),
        navBar: _id > 0 ? editNavBar(context) : createNavBar(context),
        appBar: null);
  }
}
