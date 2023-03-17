import 'package:flutter/material.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'channel/osm_method_channel.dart';
import 'common/osm_event.dart';
import 'types/types.dart';

abstract class OSMPlatform extends PlatformInterface {
  OSMPlatform() : super(token: token);

  static late OSMPlatform _instance = MethodChannelOSM();

  static OSMPlatform get instance => _instance;

  /// Platform-specific plugins should set this with their own platform-specific
  /// class that extends [OSMPlatformInterface] when they register themselves.
  static set instance(OSMPlatform instance) {
    PlatformInterface.verifyToken(instance, token);
    _instance = instance;
  }

  static final Object token = Object();

  Stream<MapInitialization> onMapIsReady(int idMap);

  Stream<SingleTapEvent> onSinglePressMapClickListener(int idMap);

  Stream<LongTapEvent> onLongPressMapClickListener(int idMap);

  Stream<RoadTapEvent> onRoadMapClickListener(int idMap);

  Stream<GeoPointEvent> onGeoPointClickListener(int idMap);

  Stream<UserLocationEvent> onUserPositionListener(int idMap);

  Stream<RegionIsChangingEvent> onRegionIsChangingListener(int idMap);

  Future<void> init(
    int idOSM,
  );

  void close(int idOSM);
}

abstract class MobileOSMPlatform extends OSMPlatform {
  Stream<MapRestoration> onMapRestored(int idMap);

  Future<void> initPositionMap(
    int idOSM,
    GeoPoint point,
  );

  Future<void> changeTileLayer(
    int idOSM,
    CustomTile? tile,
  );

  Future<void> currentLocation(
    int idOSM,
  );

  Future<GeoPoint> getMapCenter(
    int idMap,
  );

  Future<GeoPoint> myLocation(
    int idMap,
  );

  Future<GeoPoint> pickLocation(
    int idOSM, {
    GlobalKey? key,
    String imageURL = "",
  });

  Future<void> customMarker(
    int idOSM,
    GlobalKey? globalKey,
  );

  Future<void> customUserLocationMarker(
    int idOSM,
    GlobalKey personGlobalKey,
    GlobalKey directionArrowGlobalKey,
  );

  Future<void> enableTracking(
    int idOSM, {
    bool stopFollowInDrag = false,
  });

  Future<void> addPosition(
    int idOSM,
    GeoPoint p,
  );

  Future<void> goToPosition(
    int idOSM,
    GeoPoint p,
  );

  Future<void> addMarker(
    int idOSM,
    GeoPoint p, {
    GlobalKey? globalKeyIcon,
  });

  Future<void> changeMarker(
    int idOSM,
    GeoPoint oldLocation,
    GeoPoint newLocation, {
    GlobalKey? globalKeyIcon,
  });

  Future<void> setIconMarker(
    int idOSM,
    GeoPoint point,
    GlobalKey globalKeyIcon,
  );

  Future<void> removePosition(
    int idOSM,
    GeoPoint p,
  );
  Future<void> removeMarkers(
    int idOSM,
    List<GeoPoint> markers,
  );

  Future<void> removeLastRoad(
    int idOSM,
  );

  Future<void> removeRoad(
    int idOSM,
    String roadKey,
  );
  Future<RoadInfo> drawRoad(
    int idOSM,
    GeoPoint start,
    GeoPoint end, {
    RoadType roadType = RoadType.car,
    List<GeoPoint>? interestPoints,
    RoadOption roadOption,
  });

  Future<List<RoadInfo>> drawMultipleRoad(
    int idOSM,
    List<MultiRoadConfiguration> configs, {
    MultiRoadOption commonRoadOption,
  });

  Future<void> clearAllRoads(
    int idOSM,
  );

  Future<void> drawCircle(
    int idOSM,
    CircleOSM circleOSM,
  );

  Future<void> removeCircle(
    int idOSM,
    String key,
  );

  Future<void> drawRect(
    int idOSM,
    RectOSM rectOSM,
  );

  Future<void> removeRect(
    int idOSM,
    String key,
  );

  Future<void> removeAllRect(
    int idOSM,
  );

  Future<void> removeAllCircle(
    int idOSM,
  );

  Future<void> removeAllShapes(
    int idOSM,
  );

  Future<void> customMarkerStaticPosition(
    int idOSM,
    GlobalKey? globalKey,
    String id, {
    bool refresh = false,
  });

  Future<void> staticPosition(
    int idOSM,
    List<GeoPoint> pList,
    String id,
  );

  Future<double> getZoom(
    int idOSM,
  );

  Future<void> setZoom(
    int idOSM, {
    double? zoomLevel,
    double? stepZoom,
  });

  Future<void> setStepZoom(
    int idOSM,
    int stepZoom,
  );

  Future<void> setMinimumZoomLevel(
    int idOSM,
    double minZoom,
  );

  Future<void> setMaximumZoomLevel(
    int idOSM,
    double maxZoom,
  );

  Future<void> zoomToBoundingBox(
    int idOSM,
    BoundingBox box, {
    int paddinInPixel = 0,
  });

  Future<void> disableTracking(
    int idOSM,
  );

  Future<void> visibilityInfoWindow(
    int idOSM,
    bool visible,
  );

  Future<void> advancedPositionPicker(
    int idOSM,
  );

  Future<GeoPoint> getPositionOnlyAdvancedPositionPicker(
    int idOSM,
  );

  Future<GeoPoint> selectAdvancedPositionPicker(
    int idOSM,
  );

  Future<void> cancelAdvancedPositionPicker(
    int idOSM,
  );

  Future<void> drawRoadManually(
    int idOSM,
    String roadKey,
    List<GeoPoint> road,
    RoadOption roadOption,
  );

  Future<void> mapRotation(
    int idOSM,
    double degree,
  );

  Future<void> customAdvancedPickerMarker(
    int idMap,
    GlobalKey key,
  );

  Future<void> limitArea(
    int idOSM,
    BoundingBox box,
  );

  Future<void> removeLimitArea(
    int idOSM,
  );

  Future<BoundingBox> getBounds(
    int idOSM,
  );

  Future<List<GeoPoint>> getGeoPointMarkers(
    int idOSM,
  );
}
