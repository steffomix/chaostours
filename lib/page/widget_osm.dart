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
  bool widgetActive = false;
  bool _init = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
    widgetActive = false;
  }

  late MapController controller;

  Widget osm(BuildContext context, [double zoom = 12]) {
    return OSMFlutter(
      androidHotReloadSupport: true,
      isPicker: true,
      controller: controller,
      initZoom: zoom,
      minZoomLevel: 8,
      maxZoomLevel: 19,
      stepZoom: 1.0,
      userLocationMarker: UserLocationMaker(
        personMarker: const MarkerIcon(
          icon: Icon(
            Icons.location_history_rounded,
            color: Colors.red,
            size: 48,
          ),
        ),
        directionArrowMarker: const MarkerIcon(
          icon: Icon(
            Icons.double_arrow,
            size: 48,
          ),
        ),
      ),
      roadConfiguration: RoadConfiguration(
        startIcon: const MarkerIcon(
          icon: Icon(
            Icons.person,
            size: 64,
            color: Colors.brown,
          ),
        ),
        roadColor: Colors.yellowAccent,
      ),
      markerOption: MarkerOption(
          defaultMarker: const MarkerIcon(
        icon: Icon(
          Icons.person_pin_circle,
          color: Colors.blue,
          size: 56,
        ),
      )),
    );
  }

  Widget infoBox(context) {
    var boxContent = ListTile(
      leading: IconButton(
          icon: const Icon(color: Colors.amber, size: 40, Icons.rotate_left),
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
          BottomNavigationBarItem(icon: Icon(Icons.near_me), label: 'Zurück'),
          BottomNavigationBarItem(icon: Icon(Icons.done), label: 'Speichern')
        ],
        onTap: (int id) async {
          switch (id) {
            case 0:
              Navigator.pop(context);
              break;
            case 1:
              controller.goToLocation(
                  GeoPoint(latitude: _gps.lat, longitude: _gps.lon));

              break;
            case 2:
              controller.getCurrentPositionAdvancedPositionPicker().then((pos) {
                var alias = ModelAlias.getAlias(_id);
                alias.lat = pos.latitude;
                alias.lon = pos.longitude;
                ModelAlias.update();
                AppWidgets.navigate(context, AppRoutes.editAlias, _id);
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
          BottomNavigationBarItem(icon: Icon(Icons.done), label: 'Speichern')
        ],
        onTap: (int id) async {
          switch (id) {
            case 0:
              Navigator.pop(context);
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
                addr.Address(GPS(alias.lat, alias.lon))
                    .lookupAddress()
                    .then((adr) {
                  alias.alias = adr.toString();
                  ModelAlias.insert(alias);
                  _id = alias.id;
                  Navigator.popUntil(
                      context, ModalRoute.withName(AppRoutes.listAlias.route));
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

  @override
  Widget build(BuildContext context) {
    _id = ModalRoute.of(context)?.settings.arguments as int? ?? 0;
    if (_id > 0) {
      var alias = ModelAlias.getAlias(_id);
      _gps = GPS(alias.lat, alias.lon);
      if (_address.isEmpty) {
        _address = alias.alias;
      }
      controller = MapController(
          initMapWithUserPosition: false,
          initPosition: GeoPoint(latitude: _gps.lat, longitude: _gps.lon),
          areaLimit: BoundingBox(
            east: _gps.lon + 2,
            north: _gps.lat + 2,
            south: _gps.lat - 2,
            west: _gps.lon - 2,
          ));
    } else {
      controller = MapController(initMapWithUserPosition: true);
      if (!_init) {
        GPS.gps().then(((gps) {
          _gps = gps;
          addr.Address(gps).lookupAddress().then((addr.Address address) {
            _address = address.toString();
            setState(() {});
          });
        })).whenComplete(() {
          _init = true;
        });
      }
    }
    Future.delayed(const Duration(seconds: 2), () async {
      widgetActive = true;
      var i = 0;
      var list = ModelAlias.getAll();
      while (list.isNotEmpty) {
        if (!widgetActive) {
          break;
        }
        var alias = list.last;
        try {
          Color color;
          if (alias.status == AliasStatus.public) {
            color = Colors.green;
          } else if (alias.status == AliasStatus.privat) {
            color = Colors.yellow;
          } else {
            color = Colors.red;
          }

          controller.drawCircle(CircleOSM(
            key: "circle${++i}",
            centerPoint: GeoPoint(latitude: alias.lat, longitude: alias.lon),
            radius: alias.radius.toDouble(),
            color: color,
            strokeWidth: 10,
          ));
          /*
          controller.addMarker(
              GeoPoint(latitude: alias.lat, longitude: alias.lon),
              markerIcon: const MarkerIcon(
                  icon: Icon(
                Icons.person,
                size: 64,
              )));
              */
        } catch (e, stk) {
          logger.error(e.toString(), stk);
          await Future.delayed(const Duration(seconds: 1));
        }
        list.removeLast();
      }
    });

    /// to draw
    /*
      await controller.drawCircle(CircleOSM(
        key: "circle0",
        centerPoint: GeoPoint(latitude: 47.4333594, longitude: 8.4680184),
        radius: 1200.0,
        color: Colors.red,
        strokeWidth: 0.3,
      ));

      /// to remove Circle using Key
      await controller.removeCircle("circle0");

      /// to remove All Circle in the map
      await controller.removeAllCircle();
      */

    return AppWidgets.scaffold(context,
        body: Stack(children: [
          osm(context, _id > 0 ? 17 : 12),
          infoBox(context),
        ]),
        navBar: _id > 0 ? editNavBar(context) : createNavBar(context),
        appBar: null);
  }
}
