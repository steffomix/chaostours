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

import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:http/http.dart' as http;
import 'package:chaostours/data_bridge.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';

///
import 'package:chaostours/logger.dart';
import 'package:chaostours/event_manager.dart';
import 'package:chaostours/conf/app_routes.dart';
import 'package:chaostours/conf/app_colors.dart';
import 'package:chaostours/view/app_widgets.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/address.dart' as addr;
import 'package:chaostours/osm_tools.dart';
import 'package:chaostours/model/model_alias.dart';
import 'package:chaostours/screen.dart';
import 'package:chaostours/conf/app_settings.dart';

class OsmSearchResult {
  final double lat;
  final double lon;
  final String address;

  OsmSearchResult(
      {required this.address, required this.lat, required this.lon});
}

class WidgetMapIsLoading extends StatefulWidget {
  const WidgetMapIsLoading({super.key});

  @override
  State<WidgetMapIsLoading> createState() => _WidgetMapIsLoading();
}

class EventOnOsmIsLoading {}

class _WidgetMapIsLoading extends State<WidgetMapIsLoading> {
  static final Logger logger = Logger.logger<WidgetMapIsLoading>();

  @override
  void dispose() {
    EventManager.fire<EventOnOsmIsLoading>(EventOnOsmIsLoading());
    logger.log('loading disposed');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
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

  /// screen
  //late SizeChangedLayoutNotifier screenListener;

  /// osm tools to draw circles
  final OsmTools osmTools = OsmTools();

  /// alias id
  int _id = 0;
  late ModelAlias _alias;

  /// _controller
  late MapController _controller;

  late OSMFlutter osm;

  /// init - prevent init sequence in build called twice
  bool _initialized = false;

  /// map _controller position
  late GPS _gps;

  /// search textfield
  final ValueNotifier<String> _address = ValueNotifier<String>('');
  final ValueNotifier<bool> _loading = ValueNotifier<bool>(false);

  bool debugPaintPointersEnabled = true;

  /// draw circles
  bool _widgetActive = false;
  int circleId = 0;

  /// search
  String _searchText = '';
  bool searchTextChanged = true;
  TextEditingController textController = TextEditingController(text: '');
  Duration _searchDelay = const Duration(milliseconds: 1200);
  DateTime _lastSearch = DateTime.now();

  ///searchResult
  late Screen _screen;
  final List<OsmSearchResult> searchResultList = [];

  @override
  void initState() {
    _id = 0;
    _initialized = false;
    super.initState();
    EventManager.listen<EventOnOsmIsLoading>(onOsmLoad);
    DataBridge.instance.loadCache().then((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void onOsmLoad(EventOnOsmIsLoading e) {
    drawCircles();
  }

  @override
  void dispose() {
    EventManager.remove<EventOnOsmIsLoading>(onOsmLoad);
    _widgetActive = false;
    _address.dispose();
    _controller.removeAllCircle();
    _controller.dispose();
    super.dispose();
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
            decoration: BoxDecoration(
                color: const Color.fromARGB(92, 255, 255, 255),
                border: Border.all()),
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
                          ? AppWidgets.loading('')
                          : const SizedBox(width: 30 + 5, height: 30 + 5);
                    },
                    valueListenable: _loading,
                  )),
              AppWidgets.divider(),
              ...list
            ])));
  }

  launchGoogleMaps() {
    _controller.getCurrentPositionAdvancedPositionPicker().then((p) async {
      var gps = await GPS.gps();
      var lat = gps.lat;
      var lon = gps.lon;
      var lat1 = p.latitude;
      var lon1 = p.longitude;
      GPS.launchGoogleMaps(lat, lon, lat1, lon1);
    });
  }

  BottomNavigationBar navBar(context) {
    return BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
              icon: const Icon(Icons.done),
              label: _id > 0 ? 'Speichern' : 'Erstellen'),
          const BottomNavigationBarItem(
              icon: Icon(Icons.map), label: 'Google Maps'),
          const BottomNavigationBarItem(
              icon: Icon(Icons.search), label: 'Alias'),
          const BottomNavigationBarItem(
              icon: Icon(Icons.cancel), label: 'Abbrechen'),
        ],
        onTap: (int buttonId) {
          /// get current position
          var future = _controller.getCurrentPositionAdvancedPositionPicker();
          future.then((pos) async {
            switch (buttonId) {
              case 0:
                if (_id > 0) {
                  logger.log('save/update id: $_id');
                  ModelAlias alias = _alias; //ModelAlias.getAlias(_id);
                  alias.lat = pos.latitude;
                  alias.lon = pos.longitude;

                  ModelAlias.update(_alias);
                  Navigator.pop(context);
                  Fluttertoast.showToast(msg: 'Alias location updated');
                } else {
                  /// create alias
                  String address =
                      (await addr.Address(GPS(pos.latitude, pos.longitude))
                              .lookupAddress())
                          .toString();

                  ModelAlias alias = ModelAlias(
                      lat: pos.latitude,
                      lon: pos.longitude,
                      title: address,
                      notes: '',
                      deleted: false,
                      radius: AppSettings.distanceTreshold,
                      lastVisited: DateTime.now());

                  ModelAlias.insert(alias).then((_) {
                    Navigator.pop(context);
                    Fluttertoast.showToast(msg: 'Alias created');
                  }).onError((error, stackTrace) {
                    logger.error(error.toString(), stackTrace);
                  });
                }
                break;
              case 1:
                logger.log('launch google maps');
                if (GPS.lastGps != null) {
                  launchGoogleMaps();
                } else {
                  GPS.gps().then((_) => launchGoogleMaps());
                }

                break;
              case 2:
                // search for alias
                _controller
                    .getCurrentPositionAdvancedPositionPicker()
                    .then((GeoPoint pos) {
                  List<ModelAlias> list = ModelAlias.nextAlias(
                      gps: GPS(pos.latitude, pos.longitude));
                  if (list.isNotEmpty) {
                    Navigator.pushNamed(
                        context, AppRoutes.listAliasTrackpoints.route,
                        arguments: list.first.id);
                  }
                });
                break;
              default:

                /// return to previous
                logger.log('return to last view');
                Navigator.pop(context);
            }
          }).onError((error, stackTrace) {
            logger.error(error.toString(), stackTrace);
          });
        });
  }

  Widget centerAim(context) {
    double iconsize = 20;
    return Positioned(
        left: _screen.width / 2 - iconsize / 2 + 1,
        top: (_screen.height - 130) / 2 - iconsize / 2 - 5,
        child: Icon(Icons.add_circle_outline_outlined, size: iconsize));
  }

  Future<void> drawCircles() async {
    await osmTools.renderAlias(_controller);
  }

  ///
  ///
  ///
  @override
  Widget build(BuildContext context) {
    _screen = Screen(context);

    if (!_initialized) {
      _id = ModalRoute.of(context)?.settings.arguments as int? ?? 0;
      if (_id > 0) {
        var alias = ModelAlias.getModel(_id);
        _alias = alias.clone();
        _gps = GPS(alias.lat, alias.lon);
        _address.value = alias.title;
        _controller = MapController(
            initMapWithUserPosition: false,
            initPosition: (GeoPoint(latitude: _gps.lat, longitude: _gps.lon)));

        _controller.listenerMapLongTapping.addListener(() {
          _controller.selectAdvancedPositionPicker().then((GeoPoint pos) {});
        });
        osm = OSMFlutter(
          mapIsLoading: const WidgetMapIsLoading(),
          androidHotReloadSupport: true,
          controller: _controller,
          isPicker: true,
          initZoom: 17,
          minZoomLevel: 8,
          maxZoomLevel: 19,
          stepZoom: 1.0,
        );
        Future.delayed(const Duration(milliseconds: 1000), () async {
          await _controller
              .goToLocation(GeoPoint(latitude: _gps.lat, longitude: _gps.lon))
              .then((_) async {
            await _controller.setZoom(zoomLevel: 17).then((_) {
              //Future.delayed(const Duration(seconds: 3), drawCircles);
            });
          });
        });
      } else {
        if (GPS.lastGps == null) {
          GPS.gps().then((GPS gps) {
            _gps = gps;
            if (mounted) {
              setState(() {});
            }
          });
          _controller = MapController(initMapWithUserPosition: true);
        } else {
          _gps = GPS.lastGps!;
          _controller = MapController(
              initMapWithUserPosition: false,
              initPosition:
                  (GeoPoint(latitude: _gps.lat, longitude: _gps.lon)));
        }
        osm = OSMFlutter(
          mapIsLoading: const WidgetMapIsLoading(),
          androidHotReloadSupport: true,
          controller: _controller,
          isPicker: true,
          initZoom: 17,
          minZoomLevel: 8,
          maxZoomLevel: 19,
          stepZoom: 1.0,
        );
      }
    } else {
      Future.delayed(const Duration(seconds: 2), drawCircles);
    }
    var body = AppWidgets.scaffold(context,
        appBar: AppBar(title: const Text('OSM & Alias')),
        body: Stack(children: [
          osm,
          centerAim(context),
          searchResultContainer(context),
          infoBox(context)
        ]),
        navBar: navBar(context));

    if (!_initialized) {
      SizeChangedLayoutNotifier(child: body);
    }

    _initialized = true;
    return body;
  }
}