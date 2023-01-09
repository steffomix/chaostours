enum Events {
  onGps,
  onTrackPoint,
  onStatusChanged,
  onMainPaneChanged,

  ;
}

class EventManager {
  static  final Map<Events, Set<Event>> _register = {
    Events.onGps: {},
    Events.onTrackPoint: {},
    Events.onMainPaneChanged: {}
  };
  
  void fnDefault (Event e){
    //
  }

  bool addListener (Events e, Event ex) => _register[e].add(ex);
  EventManager(Events ev) { 
    }
  }

  void addListener(void Function(Event) fn) => _event!.listeners.add(fn);
  void removeListener(void Function(dynamic) fn) =>
      _event!.listeners.remove(fn);

  void fire(dynamic data) {
    for (var fn in _event!.listeners) {
      fn(data);
    }
  }
}

class Event {}
