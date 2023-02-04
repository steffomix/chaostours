import 'dart:convert';
import 'dart:io';
//
import 'package:chaostours/globals.dart';

Codec<String, String> base64Codec() => utf8.fuse(base64);

double fileSize(File file) {
  double mb = file.lengthSync() / (1024 * 1024);
  return mb;
}

String timeElapsed(DateTime t1, DateTime t2, [bool short = true]) {
  DateTime t0;
  if (t1.difference(t2).isNegative) {
    t0 = t1;
    t1 = t2;
    t2 = t0;
  }
  String s = '';
  int days = t1.difference(t2).inDays;
  t2 = t2.add(Duration(days: days));
  //
  int hours = t1.difference(t2).inHours;
  t2 = t2.add(Duration(hours: hours));
  //
  int minutes = t1.difference(t2).inMinutes;
  t2 = t2.add(Duration(minutes: minutes));
  //
  int seconds = t1.difference(t2).inSeconds;
  t2 = t2.add(Duration(seconds: seconds));
  //
  int ms = t1.difference(t2).inMilliseconds;
  if (short) {
    s = Globals.debugMode ? '$hours:$minutes::$seconds.$ms' : '$hours:$minutes';
  } else {
    s = '';
    if (days > 0) {
      s += '$days Tage, ';
    }
    if (hours > 0) {
      s += '$hours Stunden, ';
    }
    if (minutes > 0) {
      s += '$minutes Minuten, ';
    }
    if (seconds > 0) {
      s += '$seconds Sekunden';
    }
  }

  return s;
}

Duration duration(DateTime t1, DateTime t2) {
  DateTime t0;
  if (t1.difference(t2).isNegative) {
    t0 = t1;
    t2 = t1;
    t1 = t0;
  }
  return t1.difference(t2);
}

String formatDate(DateTime t, [bool short = true]) {
  if (short) {
    return '${t.day}.${t.month}.${t.year} um ${t.hour}:${t.minute}';
  } else {
    return '${t.day}.${t.month}.${t.year} ${t.hour}:${t.minute}::${t.second}:::${t.millisecond}';
  }
}
