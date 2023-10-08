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
import 'dart:convert';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';

///
import 'package:chaostours/conf/app_routes.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/address.dart' as addr;
import 'package:chaostours/conf/app_settings.dart';
import 'package:chaostours/screen.dart';
import 'package:chaostours/data_bridge.dart';
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
  void initState() {
    super.initState();
    DataBridge.instance.loadCache().then((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _addressNotifier.dispose();
    mapController.removeAllCircle();
    mapController.dispose();
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
              onPressed: () {
                mapController
                    .getCurrentPositionAdvancedPositionPicker()
                    .then((loc) {
                  final gps = GPS(loc.latitude, loc.longitude);
                  mapController
                      .goToLocation(
                          GeoPoint(latitude: gps.lat, longitude: gps.lon))
                      .then((_) {
                    addr.Address(gps).lookupAddress().then((address) {
                      _addressNotifier.value = address.toString();
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
        height: screen.newHeight * 0.7,
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
    mapController.getCurrentPositionAdvancedPositionPicker().then((p) async {
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
          var future = mapController.getCurrentPositionAdvancedPositionPicker();
          future.then((pos) async {
            switch (buttonId) {
              case 0:
                if (_id > 0) {
                  if (_modelAlias == null) {
                    return;
                  }
                  logger.log('save/update id: $_id');
                  ModelAlias alias = _modelAlias!; //ModelAlias.getAlias(_id);
                  alias.gps = GPS(pos.latitude, pos.longitude);
                  alias.update().then(
                    (_) {
                      if (mounted) {
                        Navigator.pop(context);
                      }
                      Fluttertoast.showToast(msg: 'Alias location updated');
                    },
                  );
                } else {
                  /// create alias
                  String address =
                      (await addr.Address(GPS(pos.latitude, pos.longitude))
                              .lookupAddress())
                          .toString();

                  ModelAlias alias = ModelAlias(
                      gps: GPS(pos.latitude, pos.longitude),
                      title: address,
                      description: '',
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
                mapController
                    .getCurrentPositionAdvancedPositionPicker()
                    .then((GeoPoint pos) {
                  ModelAlias.nextAlias(gps: GPS(pos.latitude, pos.longitude))
                      .then((List<ModelAlias> models) {
                    if (models.isNotEmpty && mounted) {
                      Navigator.pushNamed(
                          context, AppRoutes.listAliasTrackpoints.route,
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
          }).onError((error, stackTrace) {
            logger.error(error.toString(), stackTrace);
          });
        });
  }

  /// _controller
  MapController? _mapController;
  MapController get mapController {
    return _mapController ??= _gps == null
        ? MapController(
            initMapWithUserPosition:
                const UserTrackingOption(unFollowUser: false))
        : MapController(
            initPosition: GeoPoint(latitude: _gps!.lat, longitude: _gps!.lon));
  }

  OSMOption? _osmOption;
  OSMFlutter? _osmFlutter;
  OSMFlutter get osmFlutter {
    return _osmFlutter ??= OSMFlutter(
      onMapIsReady: (bool ready) {
        mapController.removeAllCircle().then(
              (value) => osmTools.renderAlias(mapController),
            );
      },
      osmOption: _osmOption ??= const OSMOption(
        showDefaultInfoWindow: true,
        showZoomController: true,
        isPicker: true,
        zoomOption: ZoomOption(
          initZoom: 17,
          minZoomLevel: 8,
          maxZoomLevel: 19,
          stepZoom: 1.0,
        ),
      ),
      mapIsLoading: AppWidgets.loading('Loading Map'),
      //androidHotReloadSupport: true,
      controller: mapController,
    );
  }

  ///
  ///
  ///
  @override
  Widget build(BuildContext context) {
    int? id = ModalRoute.of(context)?.settings.arguments as int?;

    if (id != null && _modelAlias == null) {
      _id = id;
      ModelAlias.byId(_id).then(
        (ModelAlias? model) {
          if (model == null) {
            /*Future.delayed(const Duration(milliseconds: 100),
                () => Navigator.pop(context));*/
          } else {
            _modelAlias = model;
            _gps = model.gps;
            _addressNotifier.value = model.title;
            if (mounted) {
              setState(() {});
            }
          }
        },
      ).onError((error, stackTrace) {
        logger.error(error, stackTrace);
      });
      return AppWidgets.scaffold(context,
          appBar: AppBar(title: const Text('OSM & Alias')),
          body: AppWidgets.loading('Loading Alias'));
    } else {
      return AppWidgets.scaffold(context,
          appBar: AppBar(title: const Text('OSM & Alias')),
          body:
              Stack(children: [osmFlutter, searchResultContainer(), infoBox()]),
          navBar: navBar(context));
    }
  }
}
