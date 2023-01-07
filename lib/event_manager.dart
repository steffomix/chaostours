enum Events {
  onGps;
}

class EventManager {
  static final Map<Events, _Event> _events = {};
  _Event? _event;

  EventManager(Events ev) {
    var e = _events[ev];
    if (e == null) {
      Map<Events, _Event> entry = {ev: _Event()};
      _events.addEntries(entry.entries);
      _event = _events[ev];
    }
  }

  void addListener(void Function(dynamic) fn) => _event!.listeners.add(fn);
  void removeListener(void Function(dynamic) fn) =>
      _event!.listeners.remove(fn);

  void fire(dynamic data) {
    for (var fn in _event!.listeners) {
      fn(data);
    }
  }
}

class _Event {
  final Set<void Function(dynamic)> listeners = {};
  _Event();
}
