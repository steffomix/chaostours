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

import 'package:chaostours/database/cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'dart:convert';

import 'dart:math' as math;
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';

///
import 'package:chaostours/conf/app_routes.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/address.dart' as addr;
import 'package:chaostours/conf/app_user_settings.dart';
import 'package:chaostours/screen.dart';
import 'package:chaostours/event_manager.dart';
import 'package:chaostours/view/app_widgets.dart';
import 'package:chaostours/osm_tools.dart';
import 'package:chaostours/model/model_alias.dart';

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
  /*
  @override
  Widget build(BuildContext context) {
    return AppWidgets.scaffold(context,
        body: AppWidgets.loading('Widget under construction'));
  }
  */
  static final Logger logger = Logger.logger<WidgetOsm>();

  /// screen
  //late SizeChangedLayoutNotifier screenListener;

  /// osm tools to draw circles
  final OsmTools osmTools = OsmTools();

  /// alias id
  int _id = 0;
  ModelAlias? _modelAlias;

  /// map _controller position
  GPS? _gps;

  /// search textfield
  final ValueNotifier<String> _addressNotifier = ValueNotifier<String>('');
  final ValueNotifier<bool> _loading = ValueNotifier<bool>(false);

  /// search
  String _searchText = '';
  bool _searchTextChanged = true;
  final _textController = TextEditingController(text: '');
  final _searchDelay = const Duration(milliseconds: 1200);
  DateTime _lastSearch = DateTime.now();

  ///searchResult
  final List<OsmSearchResult> searchResultList = [];

  @override
  void dispose() {
    EventManager.remove<EventOnBackgroundUpdate>(onBackgroundLookup);
    EventManager.remove<EventOnForegroundTracking>(onTracking);
    _addressNotifier.dispose();
    _loading.dispose();
    _textController.dispose();
    mapController.removeAllCircle();
    mapController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    EventManager.listen<EventOnBackgroundUpdate>(onBackgroundLookup);
    EventManager.listen<EventOnForegroundTracking>(onTracking);
    super.initState();
  }

  void onBackgroundLookup(EventOnBackgroundUpdate e) {}

  void onTracking(EventOnForegroundTracking e) async {
    osmTools.renderAlias(mapController);
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
    _searchTextChanged = false;
    _loading.value = true;
    setState(() {});
  }

  Widget infoBox() {
    var boxContent = Column(children: [
      ListTile(

          /// search icon
          trailing: IconButton(
              icon: const Icon(Icons.search, size: 40),
              onPressed: () {
                if (_searchTextChanged) {
                  lookupGps();
                }
              }),

          /// search text field
          title: TextField(
              controller: _textController,
              decoration: InputDecoration(
                  labelStyle: TextStyle(color: Theme.of(context).hintColor),
                  label: const Text(
                      'Search order: Country, City, Street, House number')),
              onChanged: (val) {
                _searchTextChanged = true;
                _searchText = val;
                lookupGps(val);
              })),

      /// map address
      ListTile(

          /// icon update map address
          trailing: IconButton(
              icon: const Icon(size: 40, Icons.rotate_left),

              /// on pressed move to location
              onPressed: () async {
                GeoPoint loc = await mapController.centerMap;
                final gps = GPS(loc.latitude, loc.longitude);
                await mapController.goToLocation(
                    GeoPoint(latitude: gps.lat, longitude: gps.lon));
                addr.Address address = await addr.Address(gps)
                    .lookup(OsmLookupConditions.onUserRequest);

                _addressNotifier.value = address.alias;
              }),

          /// _address value
          title: ValueListenableBuilder(
              valueListenable: _addressNotifier,
              builder: (context, value, child) => Text(
                    _addressNotifier.value,
                    maxLines: 3,
                  )),
          leading: IconButton(
              icon: const Icon(Icons.copy, size: 20),
              onPressed: () async {
                await Clipboard.setData(
                    ClipboardData(text: _addressNotifier.value));
              })
          //subtitle: Text('GPS: $_gps'),
          )
    ]);

    return SizedBox(
        height: 160,
        width: 1000,
        child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: const Color.fromARGB(92, 255, 255, 255),
                border: Border.all()),
            child: boxContent));
  }

  List<Widget> searchResultWidgetList = [];

  Widget searchResultContainer() {
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
                  mapController.goToLocation(
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
    final screen = Screen(context);
    return Positioned(
        top: 170,
        left: 10,
        width: screen.width * 0.95,
        height: screen.height * 0.7,
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
                          ? AppWidgets.loading(const Text(''))
                          : const SizedBox(width: 30 + 5, height: 30 + 5);
                    },
                    valueListenable: _loading,
                  )),
              AppWidgets.divider(),
              ...list
            ])));
  }

  launchGoogleMaps() {
    mapController.centerMap.then((GeoPoint geoPoint) async {
      var gps = await GPS.gps();
      var lat = gps.lat;
      var lon = gps.lon;
      var lat1 = geoPoint.latitude;
      var lon1 = geoPoint.longitude;
      GPS.launchGoogleMaps(lat, lon, lat1, lon1);
    });
  }

  Future<void> createAlias() async {
    var pos = await mapController.centerMap;
    if (!mounted) {
      return;
    }
    AppWidgets.dialog(context: context, contents: [
      Text(_id > 0
          ? 'Update Position?'
          : 'Create new Alias on current Position?')
    ], buttons: [
      TextButton(
        child: const Text('Cancel'),
        onPressed: () => Navigator.pop(context),
      ),
      TextButton(
        child: const Text('Yes'),
        onPressed: () async {
          if (_id > 0) {
            if (_modelAlias == null) {
              return;
            }
            ModelAlias alias = _modelAlias!;
            alias.gps = GPS(pos.latitude, pos.longitude);
            await alias.update();
            Fluttertoast.showToast(msg: 'Alias location updated');
            if (mounted) {
              Navigator.pop(context);
            }
          } else {
            /// create alias
            addr.Address address =
                (await addr.Address(GPS(pos.latitude, pos.longitude))
                    .lookup(OsmLookupConditions.onUserCreateAlias));

            ModelAlias alias = ModelAlias(
                gps: GPS(pos.latitude, pos.longitude),
                title: address.alias,
                description: address.description,
                radius: await Cache.appSettingDistanceTreshold.load<int>(
                    AppUserSetting(Cache.appSettingDistanceTreshold)
                        .defaultValue as int),
                lastVisited: DateTime.now());

            alias.insert();
            Fluttertoast.showToast(msg: 'Alias created');
            if (mounted) {
              Navigator.pop(context);
              Navigator.pushNamed(context, AppRoutes.editAlias.route,
                  arguments: alias.id);
            }
          }
        },
      )
    ]);
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
        onTap: (int buttonId) async {
          /// get current position
          switch (buttonId) {
            case 0:
              createAlias();
              break;
            case 1:
              launchGoogleMaps();
              break;
            case 2:
              // search for alias
              mapController.centerMap.then((GeoPoint pos) {
                ModelAlias.byArea(gps: GPS(pos.latitude, pos.longitude))
                    .then((List<ModelAlias> models) {
                  if (models.isNotEmpty && mounted) {
                    Navigator.pushNamed(
                        context, AppRoutes.trackpointsFromAliasList.route,
                        arguments: models.first.id);
                  }
                });
              });

              break;
            default:

              /// return to previous
              logger.log('return to last view');
              Navigator.pop(context);
          }
        });
  }

  /// _controller
  MapController? _mapController;
  MapController get mapController => _mapController!;

  Future<bool> init() async {
    if (mounted) {
      int? id = ModalRoute.of(context)?.settings.arguments as int?;

      if (id != null && _modelAlias == null) {
        ModelAlias? model = await ModelAlias.byId(id);
        if (model != null) {
          _modelAlias = model;
          _gps = model.gps;
          _addressNotifier.value = model.title;
        }
      }
    }
    _gps ??= await GPS.gps();

    _mapController = MapController(
      initPosition: GeoPoint(latitude: _gps!.lat, longitude: _gps!.lon),
    );

    _mapController!.addObserver(OsmObserver(_mapController!));

    return true;
  }

  ///
  ///
  ///
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: init(),
      builder: (context, snapshot) {
        Widget? check = AppWidgets.checkSnapshot(context, snapshot);
        if (check == null) {
          OSMFlutter osmFlutter = OSMFlutter(
            onMapIsReady: (bool ready) {
              osmTools.renderAlias(mapController);
            },
            onGeoPointClicked: (GeoPoint geoPoint) {
              print(
                  'onGeoPointClicked: ${geoPoint.latitude}, ${geoPoint.longitude}');
            },
            onLocationChanged: (GeoPoint geoPoint) {
              print(
                  'onLocationChanged: ${geoPoint.latitude}, ${geoPoint.longitude}');
            },
            osmOption: const OSMOption(
              isPicker: false,
              zoomOption: ZoomOption(
                initZoom: 17,
                minZoomLevel: 4,
                maxZoomLevel: 19,
                stepZoom: 1.0,
              ),
            ),

            //mapIsLoading: AppWidgets.loading(const Text('Loading Map')),
            //androidHotReloadSupport: true,
            controller: mapController,
          );

          return AppWidgets.scaffold(context,
              appBar: AppBar(title: const Text('OSM & Alias')),
              body: Stack(
                  children: [osmFlutter, searchResultContainer(), infoBox()]),
              navBar: navBar(context));
        } else {
          return check;
        }
      },
    );
  }
}

class OsmObserver with OSMMixinObserver {
  MapController controller;
  OsmObserver(this.controller);
  int _id = 0;
  String get id {
    return (++_id).toString();
  }

  double calculateCircleSize(double zoomLevel) {
    return math.pow(2, 2.5).toDouble();
  }

  Future<void> drawMapCenter() async {
    double zoom = await controller.osmBaseController.getZoom();
    String oldId = _id.toString();
    controller.drawCircle(CircleOSM(
      key: id,
      centerPoint: await controller.centerMap,
      radius: math.pow(2, 19 - zoom + 1).toDouble(),
      color: const Color.fromARGB(255, 255, 2, 2),
      strokeWidth: 10,
    ));

    controller.removeCircle(oldId);
  }

  @override
  Future<void> mapIsReady(bool isReady) async {
    drawMapCenter();
  }

  @mustCallSuper
  Future<void> mapRestored() async {
    drawMapCenter();
  }

  @mustCallSuper
  void onSingleTap(GeoPoint position) {
    print('onSingleTap');
  }

  @mustCallSuper
  void onLongTap(GeoPoint position) {}

  @mustCallSuper
  void onRegionChanged(Region region) {
    drawMapCenter();
    print('onLongTap');
  }

  @mustCallSuper
  void onRoadTap(RoadInfo road) {
    print('onRoadTap');
  }

  @mustCallSuper
  void onLocationChanged(GeoPoint userLocation) {
    print('onLocationChanged');
  }
}
