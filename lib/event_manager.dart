import 'package:chaostours/events.dart';

enum EventKeys {
  onGps,
  onTrackPoint,
  onStatusChanged,
  onMainPaneChanged,
  ;
}

class EventManager {
  static final Map<EventKeys, Set<Event>> _register = {};

  final EventKeys eventKey;
  EventManager(this.eventKey);

  /// // create a class first
  /// class MyLister extends Event{
  ///   myData = 'blabla';
  /// }
  ///
  /// // listen with a method that receives the class
  /// listen((Event e){
  ///   e.myData;
  /// })
  bool listen(Function(Event) fn) {
    Event event = Event();
    event._fn = fn;
    return (_register[eventKey] ??= {}).add(event);
  }

  bool cancel(dynamic Function(void Function(dynamic)) event) {
    return (_register[eventKey] ??= {}).remove(event);
  }

  void fire(Event event) {
    for (var listener in _register[eventKey] ??= {}) {
      try {
        listener._fn(event);
      } catch (e) {
        print(e);
      }
    }
  }
}

class Event {
  late Function(Event) _fn;
}
