/*
Copyright 2023 Stefan Brinkmann <st.brinkmann@gmail.com>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:chaostours/conf/app_user_settings.dart';
import 'package:chaostours/database/cache.dart';
// import 'package:device_calendar/device_calendar.dart';
//

Codec<String, String> base64Codec() => utf8.fuse(base64);

double fileSize(File file) {
  double mb = file.lengthSync() / (1024 * 1024);
  return mb;
}

String twoDigits(int n) => n.toString().padLeft(2, "0");

String formatDuration(Duration duration) {
  String negativeSign = duration.isNegative ? '-' : '';
  String twoDigitHours = twoDigits(duration.inHours.remainder(24).abs());
  String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60).abs());
  String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60).abs());
  return "$negativeSign${twoDigits(duration.inDays)}d : ${twoDigitHours}h : ${twoDigitMinutes}m : ${twoDigitSeconds}s";
}

String formatTimeRange(DateTime timeStart, DateTime timeEnd) {
  return '${twoDigits(timeStart.hour)}:${twoDigits(timeStart.minute)}::${twoDigits(timeStart.second)}'
      ' - ${twoDigits(timeEnd.hour)}:${twoDigits(timeEnd.minute)}::${twoDigits(timeEnd.second)}';
}

String formatDateTime(DateTime t) {
  String date;
  if (StaticCache.dateFormat == DateFormat.yyyymmdd) {
    date = '${t.year}.${twoDigits(t.month)}.${twoDigits(t.day)}';
  } else {
    date = '${t.day}.${twoDigits(t.month)}.${twoDigits(t.year)}';
  }
  return '$date  ${twoDigits(t.hour)}:${twoDigits(t.minute)}::${twoDigits(t.second)}';
}

String formatDate(DateTime t) {
  if (StaticCache.dateFormat == DateFormat.yyyymmdd) {
    return '${t.year}.${twoDigits(t.month)}.${twoDigits(t.day)}';
  } else {
    return '${t.day}.${twoDigits(t.month)}.${twoDigits(t.year)}';
  }
}

String formatTime(DateTime t) =>
    '${twoDigits(t.hour)}:${twoDigits(t.minute)}::${twoDigits(t.second)}';

Duration extractTime(DateTime t) {
  return Duration(
      hours: t.hour,
      minutes: t.minute,
      seconds: t.second,
      milliseconds: t.millisecond,
      microseconds: t.microsecond);
}

DateTime removeTime(DateTime time) {
  return time
    ..subtract(Duration(hours: time.hour))
    ..subtract(Duration(minutes: time.minute))
    ..subtract(Duration(seconds: time.second))
    ..subtract(Duration(milliseconds: time.millisecond))
    ..subtract(Duration(microseconds: time.microsecond));
}

String formatDateFilename(DateTime t) {
  String date;
  if (StaticCache.dateFormat == DateFormat.yyyymmdd) {
    date = '${t.year}_${twoDigits(t.month)}_${twoDigits(t.day)}';
  } else {
    date = '${t.day}_${twoDigits(t.month)}_${twoDigits(t.year)}';
  }
  return '${date}__${twoDigits(t.hour)}_${twoDigits(t.minute)}_${twoDigits(t.second)}';
}

/// credits: https://pub.dev/packages/intersperse
Iterable<T> intersperse<T>(T element, Iterable<T> iterable) sync* {
  final iterator = iterable.iterator;
  if (iterator.moveNext()) {
    yield iterator.current;
    while (iterator.moveNext()) {
      yield element;
      yield iterator.current;
    }
  }
}

/// credits: https://pub.dev/packages/intersperse
Iterable<T> intersperseOuter<T>(T element, Iterable<T> iterable) sync* {
  final iterator = iterable.iterator;
  if (iterable.isNotEmpty) {
    yield element;
  }
  while (iterator.moveNext()) {
    yield iterator.current;
    yield element;
  }
}

String cutString(String text, [int maxLength = 50]) =>
    text.length <= maxLength ? text : '${text.substring(0, maxLength)}...';

const _chars = 'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
Random _rnd = Random();

String getRandomString(int length) => String.fromCharCodes(Iterable.generate(
    length, (_) => _chars.codeUnitAt(_rnd.nextInt(_chars.length))));

Future<T> returnDelayed<T>(T value, [int ms = 100]) =>
    Future.delayed(Duration(milliseconds: ms), () => value);
