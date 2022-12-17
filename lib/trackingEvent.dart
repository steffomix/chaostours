import 'log.dart';
import 'address.dart';
import 'trackPoint.dart';
import 'util.dart' as util;
import 'gps.dart';
import 'trackingCalendar.dart';

class TrackingStatusChangedEvent {
  static final List<Function(TrackingStatusChangedEvent)> _listener = [];

  final int status;
  final TrackPoint trackPointStart;
  final TrackPoint trackPointStop;
  final Address address;
  final String time;
  final int distanceMoved;

  TrackingStatusChangedEvent(
      {required this.status,
      required this.trackPointStart,
      required this.trackPointStop,
      required this.address,
      required this.distanceMoved,
      required this.time});

  /// set status changed callback
  static void addListener(Function(TrackingStatusChangedEvent) fc) {
    for (var l in _listener) {
      if (l == fc) return;
    }
    _listener.add(fc);
  }

  static void triggerEvent(TrackPoint tp) async {
    // collect event data
    bool start = TrackPoint.status == TrackPoint.statusStart;
    TrackPoint stopped = TrackPoint.stoppedAtTrackPoint;
    TrackPoint started = TrackPoint.startedAtTrackPoint;
    String time = start
        ? util.timeElapsed(tp.time, stopped.time)
        : util.timeElapsed(tp.time, started.time);
    int distanceMoved = start ? 0 : TrackPoint.distanceMoved.round();

    Address address = await Address(stopped.gps).lookupAddress();
    // replace the dummy event with a valid
    TrackingStatusChangedEvent event = TrackingStatusChangedEvent(
        status: TrackPoint.status,
        trackPointStart: started,
        trackPointStop: stopped,
        address: address,
        distanceMoved: distanceMoved,
        time: time);
    // dispatch event
    for (var cb in _listener) {
      try {
        cb(event);
      } catch (e) {
        logError('Trigger TrackingStatusChangedEvent failed', e);
      }

      DateTime tStart = tp.time;
      DateTime tStop = start ? stopped.time : started.time;
      List<String> tasks = ['schindern', 'malochen', 'knechten', 'rackern'];
      Address address = event.address;
      String message =
          'Von ${tStart.toIso8601String()} bis ${tStop.toIso8601String()}\n';
      message += start ? 'Start von' : 'Stop bei';
      message += ' ${address.asString} \n';
      message += 'um ${DateTime.now().toString()}\n';
      message += start
          ? 'nach ${event.time}'
          : 'nach ${event.distanceMoved / 1000}km \nin ${event.time}';

      // add calendar entry
      TrackingCalendar cal = TrackingCalendar();
      try {
        cal.addEvent(
            await cal.createEvent(tStart, tStop, tasks, address, message));
      } catch (e) {
        logError('TrackingStatusChangedEvent::addEvent', e);
      }
    }
    ;
  }
}
