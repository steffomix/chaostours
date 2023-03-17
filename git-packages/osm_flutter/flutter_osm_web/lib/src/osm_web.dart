import 'package:flutter/material.dart';
import 'package:flutter_osm_interface/flutter_osm_interface.dart';
import 'package:flutter_osm_web/flutter_osm_web.dart';

class OsmWebWidget extends StatefulWidget {
  final IBaseMapController controller;
  final List<StaticPositionGeoPoint> staticPoints;
  final OnGeoPointClicked? onGeoPointClicked;
  final OnLocationChanged? onLocationChanged;
  final ValueNotifier<bool> mapIsReadyListener;
  final Widget? mapIsLoading;
  final List<GlobalKey> globalKeys;
  final Map<String, GlobalKey> staticIconGlobalKeys;
  final MarkerOption? markerOption;
  final RoadOption? roadConfiguration;
  final bool showDefaultInfoWindow;
  final bool isPicker;
  final bool trackMyPosition;
  final ValueNotifier<Widget?> dynamicMarkerWidgetNotifier;
  final double stepZoom;
  final double initZoom;
  final double minZoomLevel;
  final double maxZoomLevel;
  final Function(bool)? onMapIsReady;
  final UserLocationMaker? userLocationMarker;

  OsmWebWidget({
    Key? key,
    required this.controller,
    this.onGeoPointClicked,
    this.onLocationChanged,
    required this.mapIsReadyListener,
    this.mapIsLoading,
    required this.globalKeys,
    this.staticIconGlobalKeys = const {},
    this.trackMyPosition = false,
    this.markerOption,
    this.roadConfiguration,
    this.showDefaultInfoWindow = false,
    this.isPicker = false,
    required this.dynamicMarkerWidgetNotifier,
    this.staticPoints = const [],
    this.stepZoom = 1.0,
    this.initZoom = 2,
    this.minZoomLevel = 2,
    this.maxZoomLevel = 18,
    this.onMapIsReady,
    this.userLocationMarker,
  }) : super(key: key);

  @override
  OsmWebWidgetState createState() => OsmWebWidgetState();
}

class OsmWebWidgetState extends State<OsmWebWidget> with AndroidLifecycleMixin {
  late WebOsmController controller;

  GlobalKey? get defaultMarkerKey => widget.globalKeys[0];

  GlobalKey? get advancedPickerMarker => widget.globalKeys[1];

  GlobalKey? get startIconKey => widget.globalKeys[2];

  GlobalKey? get endIconKey => widget.globalKeys[3];

  GlobalKey? get middleIconKey => widget.globalKeys[4];

  GlobalKey? get dynamicMarkerKey => widget.globalKeys[5];

  GlobalKey get personIconMarkerKey => widget.globalKeys[6];

  GlobalKey get arrowDirectionMarkerKey => widget.globalKeys[7];
  late Key keyWidget = GlobalKey();

  @override
  void initState() {
    super.initState();
    controller = WebOsmController();
    if (widget.mapIsLoading == null) {
      widget.mapIsReadyListener.value = false;
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(
      key: keyWidget,
      viewType: FlutterOsmPluginWeb.getViewType(),
      onPlatformViewCreated: onPlatformViewCreated,
    );
  }

  Future<void> onPlatformViewCreated(int id) async {
    controller.init(this, id);
    controller.createHtml();
    controller.addObserver(this);
    (OSMPlatform.instance as FlutterOsmPluginWeb).setWebMapController(
      id,
      controller,
    );
    (widget.controller as BaseMapController).setBaseOSMController(controller);
    widget.controller.init();
  }

  @override
  void configChanged() {}

  @override
  void mapIsReady(bool isReady) {
    if (widget.controller.osMMixin != null) {
      Future.delayed(Duration(milliseconds: 10), () async {
        await widget.controller.osMMixin!.mapIsReady(isReady);
      });
    }
  }
}
