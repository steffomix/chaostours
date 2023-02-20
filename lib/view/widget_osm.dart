import 'package:chaostours/model/model_alias.dart';
import 'package:chaostours/screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:flutter/services.dart';

///
import 'package:chaostours/logger.dart';
import 'package:chaostours/view/app_widgets.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/address.dart' as addr;
import 'package:chaostours/event_manager.dart';
import 'package:url_launcher/url_launcher_string.dart';

class EventTextfield {
  final TextEditingController controller;
  EventTextfield(this.controller);
}

class WidgetTextField extends StatefulWidget {
  const WidgetTextField({super.key});

  @override
  State<WidgetTextField> createState() => _WidgetTextField();
}

class _WidgetTextField extends State<WidgetTextField> {
  static final Logger logger = Logger.logger<WidgetTextField>();

  TextEditingController controller = TextEditingController();

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: (val) {
        EventManager.fire<EventTextfield>(EventTextfield(controller));
        //
      },
    );
  }
}

///
class WidgetOsm extends StatefulWidget {
  const WidgetOsm({super.key});

  @override
  State<WidgetOsm> createState() => _WidgetOsm();
}

class _WidgetOsm extends State<WidgetOsm> {
  static final Logger logger = Logger.logger<WidgetOsm>();
  static TextEditingController textController = TextEditingController();

  /// controller
  MapController controller = MapController(initMapWithUserPosition: true);

  /// map controller position
  GPS _gps = GPS(0, 0);

  /// search textfield
  ValueNotifier<String> _address = ValueNotifier<String>('');

  /// alias id
  int _id = 0;

  /// draw circles
  bool widgetActive = false;

  /// search
  String search = '';
  Duration searchDelay = const Duration(milliseconds: 3000);
  DateTime lastSearch = DateTime.now();

  @override
  void initState() {
    super.initState();
  }

  _WidgetOsm() {
    EventManager.listen<EventTextfield>(onTextfieldChanged);
  }

  void onTextfieldChanged(EventTextfield e) {
    lookupGps(e.controller.text);
  }

  @override
  void dispose() {
    EventManager.remove<EventTextfield>(onTextfieldChanged);
    _address.dispose();
    controller.dispose();
    super.dispose();
    widgetActive = false;
  }

  Future<void> lookupGps(String query) async {
    var t = DateTime.now();
    if (lastSearch.add(searchDelay).isAfter(t) && query == search) {
      // return later
      Future.delayed(searchDelay, () {
        lookupGps(query);
      });
      return;
    }

    if (query != search) {
      // search has changed
      return;
    }

    /// search
    lastSearch = DateTime.now();
    var url = Uri.https('nominatim.openstreetmap.org', '/search',
        {'format': 'geojson', 'q': query});
    http.get(url).then((http.Response res) {
      if (res.body.isEmpty) {
        return;
      }
      logger.log(res.body);
      if (!res.body.contains("coordinates")) {
        return;
      }
      try {
        var json = jsonDecode(res.body);
        if ((json["features"] ?? []).length > 1) {
          return;
        }
        var futures = json["features"];
        var first = futures?[0];
        var goemetry = first?["geometry"];
        var coords = goemetry?["coordinates"];
        if (coords != null && coords.length > 1) {
          var lon = coords[0];
          var lat = coords[1];
          controller.goToLocation(GeoPoint(latitude: lat, longitude: lon));
        }
      } catch (e) {
        logger.warn(e.toString());
      }
    });
  }

  Widget infoBox(context) {
    var boxContent = Column(children: [
      ListTile(
          leading: Stack(children: [
            const Icon(Icons.search, size: 40),
            Container(
                padding: const EdgeInsets.all(10),
                child: const Text('15', style: TextStyle(fontSize: 8)))
          ]),
          title: TextField(
              controller: textController,
              onChanged: (val) {
                lookupGps(val);
                Future.delayed(
                    const Duration(milliseconds: 100), () => search = val);
              })),
      ValueListenableBuilder(
          valueListenable: _address,
          builder: (context, value, child) => ListTile(
              leading: IconButton(
                  icon: const Icon(size: 40, Icons.rotate_left),
                  onPressed: () {
                    controller
                        .getCurrentPositionAdvancedPositionPicker()
                        .then((loc) {
                      _gps = GPS(loc.latitude, loc.longitude);
                      controller
                          .goToLocation(
                              GeoPoint(latitude: _gps.lat, longitude: _gps.lon))
                          .then((_) {
                        addr.Address(_gps).lookupAddress().then((address) {
                          _address.value = address.toString();
                          //setState(() {});
                        }).onError((error, stackTrace) {
                          logger.error(error.toString(), stackTrace);
                        });
                      });
                    }).onError((error, stackTrace) {
                      logger.error(error.toString(), stackTrace);
                    });
                  }),
              title: Text(
                _address.value,
                maxLines: 3,
              ),
              trailing: IconButton(
                  icon: const Icon(Icons.copy, size: 20),
                  onPressed: () async {
                    await Clipboard.setData(
                        ClipboardData(text: _address.value));
                  })
              //subtitle: Text('GPS: $_gps'),
              ))
    ]);

    return SizedBox(
        height: 140,
        width: 1000,
        child: Container(
            alignment: Alignment.center,
            decoration:
                const BoxDecoration(color: Color.fromARGB(92, 255, 255, 255)),
            child: boxContent));
  }

  launchGoogleMaps() {
    controller.getCurrentPositionAdvancedPositionPicker().then((p) {
      var gps = GPS.lastGps!;
      var lat = gps.lat;
      var lon = gps.lon;
      var lat1 = p.latitude;
      var lon1 = p.longitude;
      var url =
          'https://www.google.com/maps/dir/?api=1&origin=$lat%2c$lon&destination=$lat1%2c$lon1&travelmode=driving';

      final intent = AndroidIntent(
          action: 'action_view',
          data: url,
          package: 'com.google.android.apps.maps');
      intent.launch();
    });
  }

  BottomNavigationBar editNavBar(context) {
    return BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.done), label: 'Speichern'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Google Maps'),
          BottomNavigationBarItem(icon: Icon(Icons.cancel), label: 'Abbrechen'),
        ],
        onTap: (int id) async {
          switch (id) {
            case 0:
              controller.getCurrentPositionAdvancedPositionPicker().then((pos) {
                var alias = ModelAlias.getAlias(_id);
                alias.lat = pos.latitude;
                alias.lon = pos.longitude;
                ModelAlias.update();
                AppWidgets.navigate(context, AppRoutes.editAlias, _id);
              });
              break;
            case 1:
              if (GPS.lastGps != null) {
                launchGoogleMaps();
              } else {
                GPS.gps().then((_) => launchGoogleMaps());
              }

              break;
            case 2:
              Navigator.pop(context);
              break;
            default:
            // do nothing
          }
        });
  }

  Widget centerAim(context) {
    double iconsize = 30;
    var screen = Screen(context);
    return Positioned(
        left: screen.width / 2 - iconsize / 2,
        top: (screen.height - 130) / 2 - iconsize / 2 - 5,
        child: Icon(Icons.add_circle_outline_outlined, size: iconsize));
  }

  BottomNavigationBar createNavBar(context) {
    return BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.done), label: 'Speichern'),
          BottomNavigationBarItem(
              icon: Icon(Icons.home), label: 'Meine Position'),
          BottomNavigationBarItem(icon: Icon(Icons.cancel), label: 'Abbruch'),
        ],
        onTap: (int id) async {
          switch (id) {
            case 0:
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
            case 1:
              GPS.gps().then(((gps) {
                _gps = gps;
                controller.goToLocation(
                    GeoPoint(latitude: _gps.lat, longitude: _gps.lon));
              }));
              break;
            case 2:
              Navigator.pop(context);
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
      _address = ValueNotifier<String>(alias.alias);
      //
      Future.delayed(
          const Duration(seconds: 1),
          () => controller
              .goToLocation(GeoPoint(latitude: _gps.lat, longitude: _gps.lon)));
    } else {
      GPS.gps().then(((gps) {
        _gps = gps;
        addr.Address(gps).lookupAddress().then((addr.Address address) {
          _address = ValueNotifier<String>(address.toString());
        });
      })).onError((e, stk) {
        _address = ValueNotifier<String>('');
      });
    }

    /// draw cirles
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
        } catch (e, stk) {
          logger.error(e.toString(), stk);
          await Future.delayed(const Duration(seconds: 1));
        }
        list.removeLast();
      }
    });

    var osm = OSMFlutter(
      //androidHotReloadSupport: true,
      isPicker: true,
      controller: controller,
      initZoom: _id > 0 ? 17 : 12,
      minZoomLevel: 8,
      maxZoomLevel: 19,
      stepZoom: 1.0,
    );

    return AppWidgets.scaffold(context,
        body: Stack(children: [osm, centerAim(context), infoBox(context)]),
        navBar: _id > 0 ? editNavBar(context) : createNavBar(context),
        appBar: null);
  }
}
