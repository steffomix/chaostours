import 'dart:math' show cos, sqrt, asin;

String timeElapsed(DateTime t1, DateTime t2) {
  DateTime t0;
  if (t1.difference(t2).isNegative) {
    t0 = t1;
    t2 = t1;
    t1 = t0;
  }
  int days;
  int hours;
  int minutes;
  int seconds;
  int ms;
  String s = '';
  days = t1.difference(t2).inDays;
  if (days > 0) {
    s += '$days Tage, ';
    t2 = t2.add(Duration(days: days));
  }
  //
  hours = t1.difference(t2).inHours;
  if (hours > 0) {
    s += '$hours Stunden, ';
    t2 = t2.add(Duration(hours: hours));
  }
  //
  minutes = t1.difference(t2).inMinutes;
  if (minutes > 0) {
    s += '$minutes Minuten, ';
    t2 = t2.add(Duration(minutes: minutes));
  }
  //
  seconds = t1.difference(t2).inSeconds;
  if (seconds > 0) {
    s += '$seconds Sekunden, ';
    t2 = t2.add(Duration(seconds: seconds));
  }
  //
  ms = t1.difference(t2).inMilliseconds;
  if (ms > 0) {
    s += '$ms Millisekunden';
  }

  return s;
}

String formatDate(DateTime t) {
  return '${t.day}.${t.month}.${t.year} ${t.hour}:${t.minute}';
}
