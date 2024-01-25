// ignore_for_file: annotate_overrides, must_call_super

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
import 'dart:convert';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'dart:math' as math;
import 'package:flutter/services.dart';

///
import 'package:chaostours/database/cache.dart';
import 'package:chaostours/conf/app_routes.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/address.dart' as addr;
import 'package:chaostours/conf/app_user_settings.dart';
import 'package:chaostours/screen.dart';
import 'package:chaostours/event_manager.dart';
import 'package:chaostours/view/system/app_widgets.dart';
import 'package:chaostours/model/model_location.dart';
import 'package:chaostours/channel/data_channel.dart';
import 'package:chaostours/conf/app_colors.dart';

class _OsmSearchResult {
  final double lat;
  final double lon;
  final String address;

  _OsmSearchResult(
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

  /// screen
  //late SizeChangedLayoutNotifier screenListener;

  /// osm tools to draw circles
  final _LocationTrackingRenderer locationRenderer =
      _LocationTrackingRenderer();

  /// location id
  int _id = 0;
  ModelLocation? _modelLocation;

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
  final List<_OsmSearchResult> searchResultList = [];

  @override
  void dispose() {
    EventManager.remove<DataChannel>(onTracking);
    super.dispose();
  }

  @override
  void initState() {
    EventManager.listen<DataChannel>(onTracking);
    super.initState();
  }

  void onTracking(DataChannel e) async {
    locationRenderer.renderLocation(mapController);
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
            searchResultList.add(_OsmSearchResult(
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
      ConstrainedBox(
          constraints: const BoxConstraints(
            maxHeight: 75,
            //maxWidth: 1000,
          ),
          child: ListTile(
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
                }),
          )),

      /// map address
      ConstrainedBox(
          constraints: const BoxConstraints(
            maxHeight: 75,
          ),
          child: ListTile(

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

                    _addressNotifier.value = address.address;
                  }),

              /// _address value
              title: ValueListenableBuilder(
                  valueListenable: _addressNotifier,
                  builder: (context, value, child) => Text(
                        _addressNotifier.value,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 3,
                      )),
              leading: IconButton(
                  icon: const Icon(Icons.copy, size: 20),
                  onPressed: () async {
                    await Clipboard.setData(
                        ClipboardData(text: _addressNotifier.value));
                  })
              //subtitle: Text('GPS: $_gps'),
              )),
    ]);

    return SizedBox(
        height: 160,
        width: 1000,
        child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: Theme.of(context).cardColor.withAlpha(100),
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

  Future<void> createLocation() async {
    var pos = await mapController.centerMap;
    if (!mounted) {
      return;
    }
    AppWidgets.dialog(context: context, contents: [
      Text(_id > 0
          ? 'Update Position?'
          : 'Create new location on current Position?')
    ], buttons: [
      TextButton(
        child: const Text('Cancel'),
        onPressed: () => Navigator.pop(context),
      ),
      TextButton(
        child: const Text('Yes'),
        onPressed: () async {
          if (_id > 0) {
            if (_modelLocation == null) {
              return;
            }
            ModelLocation location = _modelLocation!;
            location.gps = GPS(pos.latitude, pos.longitude);
            await location.update();
            Fluttertoast.showToast(msg: 'Location updated');
            if (mounted) {
              Navigator.pop(context);
            }
          } else {
            /// create location
            addr.Address address =
                (await addr.Address(GPS(pos.latitude, pos.longitude))
                    .lookup(OsmLookupConditions.onUserCreateLocation));

            ModelLocation location = ModelLocation(
                gps: GPS(pos.latitude, pos.longitude),
                title: address.address,
                description: address.addressDetails,
                radius: await Cache.appSettingDistanceTreshold.load<int>(
                    AppUserSetting(Cache.appSettingDistanceTreshold)
                        .defaultValue as int),
                lastVisited: DateTime.now());

            await location.insert();
            locationRenderer.renderLocation(mapController);
            Fluttertoast.showToast(msg: 'Location created');
            if (mounted) {
              Navigator.pop(context);
              Navigator.pushNamed(context, AppRoutes.editLocation.route,
                  arguments: location.id);
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
              icon: Icon(Icons.search), label: 'Location'),
          const BottomNavigationBarItem(
              icon: Icon(Icons.cancel), label: 'Abbrechen'),
        ],
        onTap: (int buttonId) async {
          /// get current position
          switch (buttonId) {
            case 0:
              createLocation();
              break;
            case 1:
              launchGoogleMaps();
              break;
            case 2:
              // search for location
              mapController.centerMap.then((GeoPoint pos) {
                ModelLocation.byArea(gps: GPS(pos.latitude, pos.longitude))
                    .then((List<ModelLocation> models) async {
                  if (models.isNotEmpty && mounted) {
                    await Navigator.pushNamed(
                        context, AppRoutes.editLocation.route,
                        arguments: models.first.id);
                    if (mounted) {
                      locationRenderer.renderLocation(mapController);
                    }
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

  OSMFlutter? _osmFlutter;
  MapController? _mapController;
  MapController get mapController => _mapController!;

  Future<bool> init() async {
    if (mounted) {
      _id = (ModalRoute.of(context)?.settings.arguments as int?) ?? 0;

      if (_id > 0 && _modelLocation == null) {
        ModelLocation? model = await ModelLocation.byId(_id);
        if (model != null) {
          _modelLocation = model;
          _gps = model.gps;
          _addressNotifier.value = model.title;
        }
      }
    }
    _gps ??= await GPS.gps();

    _mapController = MapController(
      initPosition: GeoPoint(latitude: _gps!.lat, longitude: _gps!.lon),
    );

    _mapController?.listenerRegionIsChanging.addListener(() {
      MapCenter.draw(mapController);
    });

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
          _osmFlutter ??= OSMFlutter(
            onMapIsReady: (bool ready) {
              Future.delayed(const Duration(seconds: 2), () {
                MapCenter.draw(mapController);
                locationRenderer.renderLocation(mapController);
              });
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
            controller: mapController,
          );
          return AppWidgets.scaffold(context,
              appBar: AppBar(title: const Text('OSM & Location')),
              body: Stack(
                  children: [_osmFlutter!, searchResultContainer(), infoBox()]),
              navBar: navBar(context));
        } else {
          return check;
        }
      },
    );
  }
}

class _LocationTrackingRenderer {
  static final Logger logger = Logger.logger<_LocationTrackingRenderer>();

  //static final bridge = DataBridge();
  static int circleId = 0;

  String get key {
    var k = 'circle${++circleId}';
    keys.add(k);
    return k;
  }

  String rectKey = '';

  List<String> keys = [];

  int maxRange = 30;

  List<GPS> getRange(List<GPS> source) {
    if (source.length > maxRange) {
      return source.getRange(0, maxRange).toList();
    }
    return source;
  }

  Future<void> renderLocation(MapController controller) async {
    DataChannel channel = DataChannel();

    if (channel.gpsPoints.isEmpty) {
      return;
    }
    try {
      // ignore: unused_local_variable
      GeoPoint geoPoint = await controller.centerMap;
    } catch (e) {
      return;
    }
    GeoPoint geoPoint = await controller.centerMap;
    List<GPS> gpsPoints = getRange(channel.gpsPoints);
    List<GPS> gpsCalcPoints = getRange(channel.gpsCalcPoints);
    GPS? lastStatusStanding = channel.gpsLastStatusStanding;
    while (keys.isNotEmpty) {
      controller.removeCircle(keys.removeLast());
    }

    var g = await GPS.gps();
    controller.drawCircle(CircleOSM(
      key: key,
      centerPoint: GeoPoint(latitude: g.lat, longitude: g.lon),
      radius: 10,
      color: AppColors.currentGpsDot.color,
      strokeWidth: 10,
    ));

    for (var location in await ModelLocation.byArea(
        gps: GPS(geoPoint.latitude, geoPoint.longitude), gpsArea: 1000 * 50)) {
      try {
        controller.drawCircle(CircleOSM(
          key: key,
          centerPoint:
              GeoPoint(latitude: location.gps.lat, longitude: location.gps.lon),
          radius: location.radius.toDouble(),
          color: location.privacy.color,
          strokeWidth: 10,
        ));
      } catch (e, stk) {
        logger.error(e.toString(), stk);
        await Future.delayed(const Duration(seconds: 1));
      }
    }

    /// draw gps points
    try {
      for (var gps in gpsPoints) {
        controller.drawCircle(CircleOSM(
          key: key,
          centerPoint: GeoPoint(latitude: gps.lat, longitude: gps.lon),
          radius: 3,
          color: Colors.black,
          strokeWidth: 10,
        ));
      }
      double i = 4.0;
      for (var gps in gpsCalcPoints) {
        controller.drawCircle(CircleOSM(
          key: key,
          centerPoint: GeoPoint(latitude: gps.lat, longitude: gps.lon),
          radius: (i += 0.5),
          color: AppColors.calcGpsTrackingDot.color,
          strokeWidth: 10,
        ));
      }

      if (lastStatusStanding != null) {
        controller.drawCircle(CircleOSM(
          key: key,
          centerPoint: GeoPoint(
              latitude: lastStatusStanding.lat,
              longitude: lastStatusStanding.lon),
          radius: 5,
          color: AppColors.lastTrackingStatusWithLocationDot.color,
          strokeWidth: 10,
        ));
      }
      MapCenter.draw(controller);
    } catch (e, stk) {
      logger.error(e.toString(), stk);
    }
  }
}

class MapCenter {
  static final Logger logger = Logger.logger<MapCenter>();
  static int _id = 0;
  static String get id {
    return (++_id).toString();
  }

  static Future<void> draw(MapController controller) async {
    double zoom = 5;
    try {
      zoom = await controller.getZoom();
    } catch (e, stk) {
      logger.error('draw: $e', stk);
      return;
    }
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
}

class OsmObserver with OSMMixinObserver {
  MapController controller;

  static OsmObserver? _instance;
  OsmObserver._(this.controller);

  factory OsmObserver(MapController controller) {
    return _instance ??= OsmObserver._(controller);
  }

  @override
  Future<void> mapIsReady(bool isReady) async {
    MapCenter.draw(controller);
  }

  @override
  @mustCallSuper
  Future<void> mapRestored() async {
    MapCenter.draw(controller);
    super.mapRestored();
  }

  @override
  @mustCallSuper
  void onSingleTap(GeoPoint position) {
    super.onSingleTap(position);
  }

  @override
  @mustCallSuper
  void onLongTap(GeoPoint position) {
    super.onLongTap(position);
  }

  @override
  @mustCallSuper
  void onRegionChanged(Region region) {
    MapCenter.draw(controller);
    super.onRegionChanged(region);
  }

  @override
  @mustCallSuper
  void onRoadTap(RoadInfo road) {
    super.onRoadTap(road);
  }

  @override
  @mustCallSuper
  void onLocationChanged(GeoPoint userLocation) {
    super.onLocationChanged(userLocation);
  }
}
