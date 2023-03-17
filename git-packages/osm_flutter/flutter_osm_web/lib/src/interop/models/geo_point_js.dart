@JS()
library osm_interop;

import 'package:js/js.dart';

@JS()
@anonymous
class GeoPointJs {
  external num get lon;

  external num get lat;

  // Must have an unnamed factory constructor with named arguments.
  external factory GeoPointJs({num lon, num lat});
}

@JS()
@anonymous
class GeoPointWithOrientationJs {
  external num get lon;

  external num get lat;

  external num get angle;

  // Must have an unnamed factory constructor with named arguments.
  external factory GeoPointWithOrientationJs({
    num lon,
    num lat,
    num angle,
  });
}
