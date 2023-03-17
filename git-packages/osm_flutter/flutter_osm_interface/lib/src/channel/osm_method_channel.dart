import 'dart:async';
import 'dart:collection';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_polyline_algorithm/google_polyline_algorithm.dart';
import 'package:stream_transform/stream_transform.dart';

import '../common/geo_point_exception.dart';
import '../common/osm_event.dart';
import '../common/road_exception.dart';
import '../common/utilities.dart';
import '../osm_interface.dart';
import '../types/types.dart';

class MethodChannelOSM extends MobileOSMPlatform {
  final Map<int, MethodChannel> _channels = {};

  //final Map<int, List<EventChannel>> _eventsChannels = {};
  var _streamController = StreamController<EventOSM>.broadcast();

  // Returns a filtered view of the events in the _controller, by mapId.
  Stream<EventOSM> _events(int mapId) =>
      _streamController.stream.where((event) => event.mapId == mapId);

  @override
  Future<void> init(int idOSMMap) async {
    if (!_channels.containsKey(idOSMMap)) {
      if (_streamController.isClosed) {
        _streamController = StreamController<EventOSM>.broadcast();
      }
      _channels[idOSMMap] =
          MethodChannel('plugins.dali.hamza/osmview_$idOSMMap');
      setGeoPointHandler(idOSMMap);
    }
    /*if (!_eventsChannels.containsKey(idOSMMap)) {
      _eventsChannels[idOSMMap] = [
       // EventChannel("plugins.dali.hamza/osmview_stream_$idOSMMap"),
        EventChannel("plugins.dali.hamza/osmview_stream_location_$idOSMMap"),
      ];
    }*/
  }

  @override
  Stream<MapInitialization> onMapIsReady(int idMap) {
    return _events(idMap).whereType<MapInitialization>();
  }

  @override
  Stream<MapRestoration> onMapRestored(int idMap) {
    return _events(idMap).whereType<MapRestoration>();
  }

  @override
  Stream<SingleTapEvent> onSinglePressMapClickListener(int idMap) {
    return _events(idMap).whereType<SingleTapEvent>();
  }

  @override
  Stream<LongTapEvent> onLongPressMapClickListener(int idMap) {
    return _events(idMap).whereType<LongTapEvent>();
  }

  @override
  Stream<GeoPointEvent> onGeoPointClickListener(int idMap) {
    return _events(idMap).whereType<GeoPointEvent>();
  }

  @override
  Stream<UserLocationEvent> onUserPositionListener(int idMap) {
    return _events(idMap).whereType<UserLocationEvent>();
  }

  @override
  Stream<RegionIsChangingEvent> onRegionIsChangingListener(int idMap) {
    return _events(idMap).whereType<RegionIsChangingEvent>();
  }

  @override
  Stream<RoadTapEvent> onRoadMapClickListener(int idMap) {
    return _events(idMap).whereType<RoadTapEvent>();
  }

  void setGeoPointHandler(int idMap) async {
    _channels[idMap]!.setMethodCallHandler((call) async {
      switch (call.method) {
        case "map#init":
          final result = call.arguments as bool;
          _streamController.add(MapInitialization(idMap, result));
          break;
        case "map#restored":
          _streamController.add(MapRestoration(idMap));
          break;
        case "receiveLongPress":
          final result = call.arguments;
          _streamController.add(LongTapEvent(idMap, GeoPoint.fromMap(result)));
          break;
        case "receiveSinglePress":
          final result = call.arguments;
          _streamController
              .add(SingleTapEvent(idMap, GeoPoint.fromMap(result)));
          break;
        case "receiveRoad":
          final result = call.arguments;
          _streamController.add(RoadTapEvent(idMap, RoadInfo.fromMap(result)));
          break;
        case "receiveGeoPoint":
          final result = call.arguments;
          _streamController.add(GeoPointEvent(idMap, GeoPoint.fromMap(result)));
          break;
        case "receiveUserLocation":
          final result = call.arguments;
          _streamController
              .add(UserLocationEvent(idMap, GeoPoint.fromMap(result)));
          break;
        case "receiveRegionIsChanging":
          final result = call.arguments;
          _streamController
              .add(RegionIsChangingEvent(idMap, Region.fromMap(result)));
          break;
      }
      return true;
    });
  }

  @override
  void close(int idOSM) {
    if (_channels.containsKey(idOSM)) {
      _channels.remove(idOSM);
    }
    if (_channels.isEmpty) {
      _streamController.close();
    }
  }

  @override
  Future<void> initPositionMap(
    int idOSM,
    GeoPoint point,
  ) async {
    Map requestData = {"lon": point.longitude, "lat": point.latitude};
    await _channels[idOSM]?.invokeMethod(
      "initMap",
      requestData,
    );
  }

  @override
  Future<void> currentLocation(int? idOSM) async {
    try {
      await _channels[idOSM]?.invokeMethod("currentLocation", null);
    } on PlatformException catch (e) {
      throw GeoPointException(msg: e.message);
    }
  }

  @override
  Future<GeoPoint> myLocation(int idMap) async {
    try {
      Map<String, dynamic> map =
          (await (_channels[idMap]!.invokeMapMethod("user#position")))!;
      return GeoPoint(latitude: map["lat"], longitude: map["lon"]);
    } on PlatformException catch (e) {
      throw GeoPointException(msg: e.message);
    }
  }

  @override
  Future<void> addPosition(int idOSM, GeoPoint p) async {
    Map requestData = {"lon": p.longitude, "lat": p.latitude};
    await _channels[idOSM]?.invokeMethod(
      "changePosition",
      requestData,
    );
  }

  @override
  Future<void> customMarker(int idOSM, GlobalKey? globalKey) async {
    final icon = await _capturePng(globalKey!);

    await _channels[idOSM]?.invokeMethod("marker#icon", icon);
  }

  @override
  Future<void> customMarkerStaticPosition(
    int idOSM,
    GlobalKey? globalKey,
    String id, {
    bool refresh = false,
  }) async {
    if (globalKey?.currentContext != null) {
      final icon = await _capturePng(globalKey!);

      var args = {
        "id": id,
        "bitmap": icon,
        "refresh": refresh,
      };

      await _channels[idOSM]?.invokeMethod(
        "staticPosition#IconMarker",
        args,
      );
    }
  }

  @override
  Future<void> disableTracking(int idOSM) async {
    await _channels[idOSM]?.invokeMethod('deactivateTrackMe', null);
  }

  @override
  Future<RoadInfo> drawRoad(
    int idOSM,
    GeoPoint start,
    GeoPoint end, {
    RoadType roadType = RoadType.car,
    List<GeoPoint>? interestPoints,
    RoadOption roadOption = const RoadOption.empty(),
  }) async {
    final roadInfo = RoadInfo();

    /// add point of the road
    final Map args = {
      'key': roadInfo.key,
      "wayPoints": [
        start.toMap(),
        end.toMap(),
      ]
    };

    /// add road type that will change api call to get route
    args.addAll({
      "roadType": roadType.toString().split(".").last,
    });

    /// add middle point that will pass through it
    if (interestPoints != null && interestPoints.isNotEmpty) {
      args.addAll(
        {
          "middlePoints": interestPoints.map((e) => e.toMap()).toList(),
        },
      );
    }

    args.addAll(roadOption.toMap());

    try {
      Map? map = await _channels[idOSM]?.invokeMapMethod(
        "road",
        args,
      );
      return RoadInfo.fromMap(map!);
    } on PlatformException catch (e) {
      throw RoadException(msg: e.message);
    }
  }

  @override
  Future<void> enableTracking(
    int idOSM, {
    bool stopFollowInDrag = false,
  }) async {
    await _channels[idOSM]?.invokeMethod('trackMe', stopFollowInDrag);
  }

  /// select position and show marker on it
  @override
  Future<GeoPoint> pickLocation(
    int idOSM, {
    GlobalKey? key,
    String imageURL = "",
  }) async {
    Map args = {};
    if (key != null) {
      args.addAll({"icon": await _capturePng(key)});
    }
    if (imageURL.isNotEmpty) {
      args.addAll({"imageURL": imageURL});
    }

    try {
      Map<String, dynamic>? map = (await (_channels[idOSM]
          ?.invokeMapMethod("user#pickPosition", args)));
      return GeoPoint(latitude: map!["lat"], longitude: map["lon"]);
    } on PlatformException catch (e) {
      throw GeoPointException(msg: e.message);
    }
  }

  @override
  Future<void> removeLastRoad(int idOSM) async {
    await _channels[idOSM]?.invokeMethod("delete#road");
  }

  @override
  Future<void> removePosition(int idOSM, GeoPoint p) async {
    await _channels[idOSM]
        ?.invokeMethod("user#removeMarkerPosition", p.toMap());
  }

  @override
  Future<void> setStepZoom(int idOSM, int defaultZoom) async {
    try {
      await _channels[idOSM]?.invokeMethod("change#stepZoom", defaultZoom);
    } on PlatformException catch (e) {
      print(e.message);
    }
  }

  @override
  Future<void> staticPosition(
    int idOSM,
    List<GeoPoint> pList,
    String id,
  ) async {
    try {
      List<Map<String, double>> listGeos = [];
      for (GeoPoint p in pList) {
        listGeos.add(p.toMap());
      }
      await _channels[idOSM]?.invokeMethod("staticPosition", {
        "id": id,
        "point": listGeos,
      });
    } on PlatformException catch (e) {
      print(e.message);
    }
  }

  Future<dynamic> _capturePng(GlobalKey globalKey) async {
    if (globalKey.currentContext == null) {
      throw Exception("Error to draw you custom icon");
    }
    RenderRepaintBoundary boundary =
        globalKey.currentContext!.findRenderObject() as RenderRepaintBoundary;

    ui.Image image;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      //added pixelRatio : 5 in ios to get clear image
      image = await boundary.toImage(pixelRatio: 5);
    } else {
      image = await boundary.toImage();
    }

    ByteData byteData =
        (await (image.toByteData(format: ui.ImageByteFormat.png)))!;
    Uint8List pngBytes = byteData.buffer.asUint8List();
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return {
        "icon": pngBytes.convertToString(),
        "size": globalKey.currentContext != null
            ? [
                globalKey.currentContext!.size!.width.toInt(),
                globalKey.currentContext!.size!.height.toInt()
              ]
            : iosSizeIcon
      };
    }
    return pngBytes;
  }

  @override
  Future<void> visibilityInfoWindow(int idOSM, bool visible) async {
    await _channels[idOSM]?.invokeMethod("use#visiblityInfoWindow", visible);
  }

  @override
  Future<void> drawCircle(int idOSM, CircleOSM circleOSM) async {
    Map requestData = {
      "lon": circleOSM.centerPoint.longitude,
      "lat": circleOSM.centerPoint.latitude,
      "key": circleOSM.key,
      "radius": circleOSM.radius,
      "stokeWidth": circleOSM.strokeWidth,
      "color": [
        circleOSM.color.red,
        circleOSM.color.blue,
        circleOSM.color.green,
      ],
    };
    await _channels[idOSM]?.invokeMethod("draw#circle", requestData);
  }

  @override
  Future<void> removeAllCircle(int idOSM) async {
    await _channels[idOSM]?.invokeMethod("remove#circle", null);
  }

  @override
  Future<void> removeCircle(int idOSM, String key) async {
    await _channels[idOSM]?.invokeMethod("remove#circle", key);
  }

  @override
  Future<void> advancedPositionPicker(int idOSM) async {
    await _channels[idOSM]?.invokeMethod("advanced#selection");
  }

  @override
  Future<void> cancelAdvancedPositionPicker(int idOSM) async {
    await _channels[idOSM]?.invokeMethod(
      "cancel#advanced#selection",
    );
  }

  @override
  Future<GeoPoint> selectAdvancedPositionPicker(int idOSM) async {
    Map mGeoPoint = (await (_channels[idOSM]
        ?.invokeMapMethod("confirm#advanced#selection")))!;
    return GeoPoint.fromMap(mGeoPoint);
  }

  @override
  Future<void> drawRect(int idOSM, RectOSM rectOSM) async {
    Map requestData = {
      "lon": rectOSM.centerPoint.longitude,
      "lat": rectOSM.centerPoint.latitude,
      "key": rectOSM.key,
      "distance": rectOSM.distance,
      "stokeWidth": rectOSM.strokeWidth,
      "color": [
        rectOSM.color.red,
        rectOSM.color.blue,
        rectOSM.color.green,
      ],
    };
    await _channels[idOSM]?.invokeMethod("draw#rect", requestData);
  }

  @override
  Future<void> removeRect(int idOSM, String key) async {
    await _channels[idOSM]?.invokeMethod("remove#rect", key);
  }

  @override
  Future<void> removeAllRect(int idOSM) async {
    await _channels[idOSM]?.invokeMethod("remove#rect", null);
  }

  @override
  Future<void> removeAllShapes(int idOSM) async {
    await _channels[idOSM]?.invokeMethod("clear#shapes");
  }

  /// get position without finish advanced picker
  @override
  Future<GeoPoint> getPositionOnlyAdvancedPositionPicker(int idOSM) async {
    try {
      Map? mGeoPoint = (await (_channels[idOSM]
          ?.invokeMapMethod("get#position#advanced#selection")));
      return GeoPoint.fromMap(mGeoPoint!);
    } on Exception catch (e) {
      throw Exception(e);
    }
  }

  @override
  Future<void> goToPosition(int idOSM, GeoPoint p) async {
    Map requestData = {"lon": p.longitude, "lat": p.latitude};
    await _channels[idOSM]?.invokeMethod(
      "goto#position",
      requestData,
    );
  }

  @override
  Future<void> drawRoadManually(
    int idOSM,
    String roadKey,
    List<GeoPoint> road,
    RoadOption roadOption,
  ) async {
    final coordinates = road.map((e) => e.toListNum()).toList();
    final encodedCoordinates = encodePolyline(coordinates);
    Map<String, dynamic> data = {
      'key': roadKey,
      "road": encodedCoordinates,
      "roadWidth": roadOption.roadWidth,
    };
    data.addAll(Map.from(roadOption.toMap()));

    await _channels[idOSM]?.invokeMethod(
      "drawRoad#manually",
      data,
    );
  }

  @override
  Future<void> mapRotation(
    int idOSM,
    double degree,
  ) async {
    await _channels[idOSM]?.invokeMethod(
      "map#orientation",
      degree,
    );
  }

  @override
  Future<void> customAdvancedPickerMarker(
    int idMap,
    GlobalKey key,
  ) async {
    final icon = await _capturePng(key);
    await _channels[idMap]!.invokeMethod("advancedPicker#marker#icon", icon);
  }

  @override
  Future<void> limitArea(int idOSM, BoundingBox box) async {
    await _channels[idOSM]?.invokeMethod("limitArea", [
      box.north,
      box.east,
      box.south,
      box.west,
    ]);
  }

  @override
  Future<void> removeLimitArea(int idOSM) async {
    await _channels[idOSM]?.invokeMethod("remove#limitArea");
  }

  @override
  Future<void> customUserLocationMarker(
    int idOSM,
    GlobalKey personGlobalKey,
    GlobalKey directionArrowGlobalKey,
  ) async {
    final iconPerson = await _capturePng(personGlobalKey);
    final iconArrowDirection = await _capturePng(directionArrowGlobalKey);
    HashMap<String, dynamic> args = HashMap();

    args["personIcon"] = iconPerson;
    args["arrowDirectionIcon"] = iconArrowDirection;

    await _channels[idOSM]?.invokeMethod("user#locationMarkers", args);
  }

  @override
  Future<void> addMarker(
    int idOSM,
    GeoPoint p, {
    GlobalKey? globalKeyIcon,
  }) async {
    Map<String, dynamic> args = {"point": p.toMap()};
    if (globalKeyIcon != null) {
      var icon = await _capturePng(globalKeyIcon);

      args["icon"] = icon;
    }

    await _channels[idOSM]?.invokeMethod("add#Marker", args);
  }

  @override
  Future<void> setMaximumZoomLevel(int idOSM, double maxZoom) async {
    await _channels[idOSM]?.invokeMethod("set#minZoom", maxZoom);
  }

  @override
  Future<void> setMinimumZoomLevel(int idOSM, double minZoom) async {
    await _channels[idOSM]?.invokeMethod("set#maxZoom", minZoom);
  }

  @override
  Future<double> getZoom(int idOSM) async {
    return await _channels[idOSM]?.invokeMethod('get#Zoom');
  }

  Future<void> setZoom(
    int idOSM, {
    double? zoomLevel,
    double? stepZoom,
  }) async {
    var args = {};
    if (zoomLevel != null) {
      args["zoomLevel"] = zoomLevel;
    } else if (stepZoom != null) {
      args["stepZoom"] = stepZoom;
    }
    await _channels[idOSM]?.invokeMethod('Zoom', args);
  }

  @override
  Future<GeoPoint> getMapCenter(int idMap) async {
    final result = await _channels[idMap]?.invokeMethod('map#center', []);
    return GeoPoint.fromMap(result);
  }

  @override
  Future<BoundingBox> getBounds(int idOSM) async {
    final Map mapBounds = await _channels[idOSM]?.invokeMethod('map#bounds');
    return BoundingBox.fromMap(mapBounds);
  }

  @override
  Future<void> zoomToBoundingBox(
    int idOSM,
    BoundingBox box, {
    int paddinInPixel = 0,
  }) async {
    final Map<String, dynamic> args = {};
    args.addAll(box.toMap());
    args.putIfAbsent("padding", () => paddinInPixel);
    await _channels[idOSM]!.invokeMethod(
      "zoomToRegion",
      args,
    );
  }

  @override
  Future<void> setIconMarker(
    int idOSM,
    GeoPoint point,
    GlobalKey<State<StatefulWidget>> globalKeyIcon,
  ) async {
    Map<String, dynamic> args = {"point": point.toMap()};

    args["icon"] = await _capturePng(globalKeyIcon);

    try {
      await _channels[idOSM]?.invokeMethod("update#Marker", args);
    } on PlatformException {
      throw Exception("marker not exist");
    }
  }

  @override
  Future<void> clearAllRoads(
    int idOSM,
  ) async {
    await _channels[idOSM]?.invokeMethod("clear#roads");
  }

  @override
  Future<List<RoadInfo>> drawMultipleRoad(
    int idOSM,
    List<MultiRoadConfiguration> configs, {
    MultiRoadOption commonRoadOption = const MultiRoadOption.empty(),
  }) async {
    final len = configs.length;
    final roadInfos = <RoadInfo>[];
    final args = configs.toListMap(
      commonRoadOption: commonRoadOption,
    );
    for (var i = 0; i < len; i++) {
      final roadInfo = RoadInfo();
      roadInfos.add(roadInfo);
      args[i]['key'] = roadInfo.key;
    }

    final List result =
        (await _channels[idOSM]?.invokeListMethod("draw#multi#road", args))!;
    final List<Map<String, dynamic>> mapRoadInfo =
        result.map((e) => Map<String, dynamic>.from(e)).toList();
    return mapRoadInfo
        .asMap()
        .entries
        .map((entry) => roadInfos[entry.key].copyFromMap(map: entry.value))
        .toList();
  }

  @override
  Future<List<GeoPoint>> getGeoPointMarkers(int idOSM) async {
    final list = await _channels[idOSM]!.invokeListMethod("get#geopoints");
    return (list as List).map((e) => GeoPoint.fromMap(e)).toList();
  }

  @override
  Future<void> changeMarker(
    int idOSM,
    GeoPoint oldLocation,
    GeoPoint newLocation, {
    GlobalKey? globalKeyIcon,
  }) async {
    Map<String, dynamic> args = {
      "new_location": newLocation.toMap(),
      "old_location": oldLocation.toMap(),
    };
    if (globalKeyIcon != null) {
      final icon = await _capturePng(globalKeyIcon);
      args["new_icon"] = icon;
    }
    await _channels[idOSM]!.invokeMethod("change#Marker", args);
  }

  @override
  Future<void> changeTileLayer(int idOSM, CustomTile? tile) async {
    await _channels[idOSM]!.invokeMethod("change#tile", tile?.toMap() ?? null);
  }

  @override
  Future<void> removeRoad(int idOSM, String roadKey) async {
    await _channels[idOSM]!.invokeMethod("delete#road", roadKey);
  }

  @override
  Future<void> removeMarkers(int idOSM, List<GeoPoint> markers) async {
    await _channels[idOSM]!.invokeMethod(
      "delete#markers",
      markers.map((e) => e.toMap()).toList(),
    );
  }
}

extension config on MethodChannelOSM {
  Future<void> configureZoomMap(
    int idOSM,
    double initZoom,
    double minZoomLevel,
    double maxZoomLevel,
    double stepZoom,
  ) async {
    var args = {
      "initZoom": initZoom,
      "minZoomLevel": minZoomLevel,
      "maxZoomLevel": maxZoomLevel,
      "stepZoom": stepZoom,
    };

    await _channels[idOSM]?.invokeMethod('config#Zoom', args);
  }

  Future<void> initIosMap(int idOSM, GlobalKey key) async {
    await _channels[idOSM]?.invokeMethod("init#ios#map");

    final icon = await _capturePng(key);

    await _channels[idOSM]?.invokeMethod("setDefaultIOSIcon", icon);
  }
}

extension mapCache on MethodChannelOSM {
  Future<void> saveCacheMap(int id) async {
    await _channels[id]?.invokeMethod("map#saveCache#view");
  }

  Future<void> removeCache(int id) async {
    await _channels[id]?.invokeMethod("removeCache");
  }

  Future<void> clearCacheMap(int id) async {
    await _channels[id]?.invokeMethod("map#clearCache#view");
  }

  Future<void> setCacheMap(int id) async {
    await _channels[id]?.invokeMethod("map#setCache");
  }
}
