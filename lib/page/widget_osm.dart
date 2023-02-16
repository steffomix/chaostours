import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';

///
import 'package:chaostours/logger.dart';
import 'package:chaostours/widget/widgets.dart';

///
class WidgetOsm extends StatefulWidget {
  const WidgetOsm({super.key});

  @override
  State<WidgetOsm> createState() => _WidgetOsm();
}

class _WidgetOsm extends State<WidgetOsm> {
  static final Logger logger = Logger.logger<WidgetOsm>();

  MapController controller = MapController(
    initMapWithUserPosition: false,
    initPosition: GeoPoint(latitude: 47.4358055, longitude: 8.4737324),
    areaLimit: BoundingBox(
      east: 10.4922941,
      north: 47.8084648,
      south: 45.817995,
      west: 5.9559113,
    ),
  );

  Widget osm() {
    return OSMFlutter(
      androidHotReloadSupport: true,
      showZoomController: true,
      isPicker: true,
      controller: controller,
      showDefaultInfoWindow: true,
      trackMyPosition: true,
      initZoom: 12,
      minZoomLevel: 5,
      maxZoomLevel: 19,
      stepZoom: 1.0,
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Widget body() {
    return Container(child: osm());
    return ListBody(
      children: [
        Row(
          children: const [Text('test'), Text('2')],
        ),
        Container(child: osm())
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppWidgets.scaffold(context,
        body: body(), navBar: null, appBar: null);
  }

  BottomNavigationBar bottomNavBar(context) {
    return BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.done), label: 'OK'),
          BottomNavigationBarItem(icon: Icon(Icons.done), label: 'OK')
        ],
        onTap: (int id) async {
          var bounds = await controller.bounds;
          var location =
              await controller.getCurrentPositionAdvancedPositionPicker();
          logger.log('BottomNavBar tapped but no method connected');
          setState(() {});
          //eventBusTapBottomNavBarIcon.fire(Tapped(id));
        });
  }
}
