// ignore_for_file: prefer_final_fields

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
import 'package:chaostours/model/model_alias.dart';
import 'package:chaostours/screen.dart';

class OsmSearchResult {
  final double lat;
  final double lon;
  final String address;

  OsmSearchResult(
      {required this.address, required this.lat, required this.lon});
}

///
class WidgetOsm extends StatefulWidget {
  const WidgetOsm({super.key});

  @override
  State<WidgetOsm> createState() => _WidgetOsm();
}

class _WidgetOsm extends State<WidgetOsm> {
  static final Logger logger = Logger.logger<WidgetOsm>();

  /// _controller
  MapController _controller = MapController(initMapWithUserPosition: true);

  /// init - prevent init sequence in build called twice
  bool _initialized = false;

  /// map _controller position
  GPS _gps = GPS(0, 0);

  /// search textfield
  final ValueNotifier<String> _address = ValueNotifier<String>('');
  final ValueNotifier<bool> _loading = ValueNotifier<bool>(false);

  /// alias id
  int _id = 0;

  /// draw circles
  bool _widgetActive = false;

  /// search
  static String _searchText = '';
  bool searchTextChanged = true;
  TextEditingController textController =
      TextEditingController(text: _searchText);
  Duration _searchDelay = const Duration(milliseconds: 1200);
  DateTime _lastSearch = DateTime.now();

  ///searchResult
  late Screen _screen;
  final List<OsmSearchResult> searchResultList = [];

  @override
  void initState() {
    super.initState();
  }

  _WidgetOsm();

  @override
  void dispose() {
    _address.dispose();
    _controller.dispose();
    super.dispose();
    _widgetActive = false;
  }

  Future<void> lookupGps([String? query]) async {
    var time = DateTime.now();
    if (_lastSearch.add(_searchDelay).isAfter(time)) {
      // return later
      Future.delayed(_searchDelay, () {
        lookupGps(query);
      });
      return;
    }
    query = (query ??= _searchText).trim();
    if (query.trim().isEmpty) {
      return;
    }

    if (query != _searchText) {
      // search has changed
      return;
    }

    /// search
    var url = Uri.https('nominatim.openstreetmap.org', '/search',
        {'format': 'geojson', 'q': query});
    logger.log(url.toString());
    http.get(url).then((http.Response res) {
      if (res.body.isEmpty) {
        return;
      }
      logger.log(res.body);
      if (!res.body.contains("FeatureCollection")) {
        return;
      }
      try {
        var json = jsonDecode(res.body);
        var futures = json["features"] ?? [];

        /// check result count
        if (futures.isEmpty) {
          return;
        }

        searchResultList.clear();
        for (var f in futures) {
          try {
            searchResultList.add(OsmSearchResult(
                address: f['properties']['display_name'],
                lat: f['geometry']['coordinates'][1],
                lon: f['geometry']['coordinates'][0]));
          } catch (e, stk) {
            logger.error(e.toString(), stk);
          }
        }
        setState(() {});
      } catch (e) {
        logger.warn(e.toString());
      }
    }).onError((error, stackTrace) {
      logger.error(error.toString(), stackTrace);
    }).whenComplete(() {
      _loading.value = false;
    });

    _lastSearch = time;
    searchTextChanged = false;
    _loading.value = true;
    setState(() {});
  }

  Widget infoBox(context) {
    var boxContent = Column(children: [
      ListTile(

          /// search icon
          trailing: IconButton(
              icon: const Icon(Icons.search, size: 40),
              onPressed: () {
                if (searchTextChanged) {
                  lookupGps();
                }
              }),

          /// search text field
          title: TextField(
              controller: textController,
              onChanged: (val) {
                searchTextChanged = true;
                _searchText = val;
                lookupGps(val);
              })),

      /// map address
      ListTile(

          /// icon update map address
          trailing: IconButton(
              icon: const Icon(size: 40, Icons.rotate_left),

              /// on pressed move to location
              onPressed: () {
                _controller
                    .getCurrentPositionAdvancedPositionPicker()
                    .then((loc) {
                  _gps = GPS(loc.latitude, loc.longitude);
                  _controller
                      .goToLocation(
                          GeoPoint(latitude: _gps.lat, longitude: _gps.lon))
                      .then((_) {
                    addr.Address(_gps).lookupAddress().then((address) {
                      _address.value = address.toString();
                    }).onError((error, stackTrace) {
                      logger.error(error.toString(), stackTrace);
                    });
                  });
                }).onError((error, stackTrace) {
                  logger.error(error.toString(), stackTrace);
                });
              }),

          /// _address value
          title: ValueListenableBuilder(
              valueListenable: _address,
              builder: (context, value, child) => Text(
                    _address.value,
                    maxLines: 3,
                  )),
          leading: IconButton(
              icon: const Icon(Icons.copy, size: 20),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: _address.value));
              })
          //subtitle: Text('GPS: $_gps'),
          )
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

  List<Widget> searchResultWidgetList = [];

  Widget searchResultContainer(context) {
    if (searchResultList.isEmpty && _loading.value == false) {
      return const SizedBox.shrink();
    }
    var list = <Widget>[];
    for (var item in searchResultList) {
      list.add(
        ListTile(
            leading: IconButton(
                icon: const Icon(
                  Icons.near_me,
                  size: 30,
                ),
                onPressed: () {
                  searchResultList.clear();
                  setState(() {});
                  _gps = GPS(item.lat, item.lon);
                  _controller.goToLocation(
                      GeoPoint(latitude: item.lat, longitude: item.lon));
                }),
            title: Text(item.address),
            trailing: IconButton(
                icon: const Icon(Icons.copy, size: 20),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(
                      text:
                          '${item.address}\nlat/lon:${item.lat},${item.lon}'));
                })),
      );
      list.add(AppWidgets.divider());
    }

    ///
    return Positioned(
        top: 140,
        left: 10,
        width: _screen.width - 20,
        height: _screen.newHeight - 240 - 20,
        child: Container(
            color: const Color.fromARGB(108, 255, 255, 255),
            child: ListView(children: [
              ListTile(
                  trailing: IconButton(
                      icon: const Icon(Icons.cancel),
                      onPressed: () {
                        searchResultList.clear();
                        setState(() {});
                      }),
                  title: const Text('Abbrechen'),
                  leading: ValueListenableBuilder(
                    builder: (context, value, child) {
                      return value == true
                          ? AppWidgets.loading(size: 30)
                          : const SizedBox(width: 30 + 5, height: 30 + 5);
                    },
                    valueListenable: _loading,
                  )),
              AppWidgets.divider(),
              ...list
            ])));
  }

  launchGoogleMaps() {
    _controller.getCurrentPositionAdvancedPositionPicker().then((p) {
      var gps = GPS.lastGps!;
      var lat = gps.lat;
      var lon = gps.lon;
      var lat1 = p.latitude;
      var lon1 = p.longitude;
      var url = 'https://www.google.com/maps/dir/?'
          'api=1&origin=$lat%2c$lon&destination=$lat1%2c$lon1&'
          'travelmode=driving';

      final intent = AndroidIntent(
          action: 'action_view',
          data: url,
          package: 'com.google.android.apps.maps');
      intent.launch();
    });
  }

  BottomNavigationBar editNavBar(context) {
    return BottomNavigationBar(
        selectedFontSize: 14,
        unselectedFontSize: 14,
        backgroundColor: AppColors.yellow.color,
        selectedItemColor: AppColors.black.color,
        unselectedItemColor: AppColors.black.color,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.done), label: 'Speichern'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Google Maps'),
          BottomNavigationBarItem(icon: Icon(Icons.cancel), label: 'Abbrechen'),
        ],
        onTap: (int id) async {
          switch (id) {
            case 0:
              _controller
                  .getCurrentPositionAdvancedPositionPicker()
                  .then((pos) {
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
    double iconsize = 20;
    return Positioned(
        left: _screen.width / 2 - iconsize / 2 + 1,
        top: (_screen.height - 130) / 2 - iconsize / 2 - 5,
        child: Icon(Icons.add_circle_outline_outlined, size: iconsize));
  }

  BottomNavigationBar createNavBar(context) {
    return BottomNavigationBar(
        selectedFontSize: 14,
        unselectedFontSize: 14,
        backgroundColor: AppColors.yellow.color,
        selectedItemColor: AppColors.black.color,
        unselectedItemColor: AppColors.black.color,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.done), label: 'Speichern'),
          BottomNavigationBarItem(
              icon: Icon(Icons.home), label: 'Meine Position'),
          BottomNavigationBarItem(icon: Icon(Icons.cancel), label: 'Abbruch'),
        ],
        onTap: (int id) async {
          switch (id) {
            case 0:
              _controller
                  .getCurrentPositionAdvancedPositionPicker()
                  .then((pos) {
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
                _controller.goToLocation(
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
    _screen = Screen(context);
    if (!_initialized) {
      _id = ModalRoute.of(context)?.settings.arguments as int? ?? 0;
      if (_id > 0) {
        var alias = ModelAlias.getAlias(_id);
        _gps = GPS(alias.lat, alias.lon);
        _address.value = alias.alias;
        //
        Future.delayed(
            const Duration(seconds: 1),
            () => _controller.goToLocation(
                GeoPoint(latitude: _gps.lat, longitude: _gps.lon)));
      } else {
        GPS.gps().then(((gps) {
          _gps = gps;
          addr.Address(gps).lookupAddress().then((addr.Address address) {
            _address.value = address.toString();
          });
        })).onError((e, stk) {
          logger.error(e.toString(), stk);
        });
      }
      _initialized = true;
    }

    /// draw cirles
    Future.delayed(const Duration(seconds: 2), () async {
      _widgetActive = true;
      var i = 0;
      var list = ModelAlias.getAll();
      while (list.isNotEmpty) {
        if (!_widgetActive) {
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

          _controller.drawCircle(CircleOSM(
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
      controller: _controller,
      initZoom: _id > 0 ? 17 : 12,
      minZoomLevel: 8,
      maxZoomLevel: 19,
      stepZoom: 1.0,
    );

    return AppWidgets.scaffold(context,
        body: Stack(children: [
          osm,
          centerAim(context),
          searchResultContainer(context),
          infoBox(context)
        ]),
        navBar: _id > 0 ? editNavBar(context) : createNavBar(context),
        appBar: null);
  }
}
