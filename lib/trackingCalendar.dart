import 'logger.dart' show log;
import 'address.dart';
import 'dart:async';
import 'locationAlias.dart';
import 'package:googleapis/calendar/v3.dart'
    show CalendarApi, Event, EventDateTime;
import 'package:crypto/crypto.dart' show sha1;
import 'dart:convert' show utf8;
import 'recourceLoader.dart';
import 'util.dart';

class TrackingCalendar {
  Event createEvent(DateTime start, DateTime end, List<String> tasksList,
      Address addr, String notes) {
    String fStart = formatDate(start);
    String fEnd = formatDate(end);
    double lat = addr.lat;
    double lon = addr.lon;
    String url = 'https://maps.google.com?q=$lat,$lon&center=$lat,$lon';
    List<Alias> aliasList = [];
    LocationAlias.alias(lat, lon, aliasList);
    String alias = aliasList.isEmpty ? '' : aliasList[0].alias;
    String address = alias == '' ? addr.asString : '$alias (${addr.asString})';
    List<String> aliasNamesList = [];
    for (var a in aliasList) {
      aliasNamesList.add(a.alias.toUpperCase());
    }
    String aliasNames =
        aliasNamesList.length > 1 ? aliasNamesList.join('; ') : ' - ';

    for (var i = 0; i < tasksList.length; i++) {
      tasksList[i]
        ..replaceAll('\r', '')
        ..replaceAll('\n', '; ');
    }
    List<String> tsvEntryParts = [
      address,
      aliasNames,
      fStart,
      fEnd,
      tasksList.join('; '),
      url
    ];
    String body = 'Ort: $address\r\n'
        'Von $fStart bis $fEnd\r\n\r\n'
        'Arbeiten:\r\n${tasksList.join('\r\n')}\r\n'
        '$notes\r\n\r\n'
        '<a href="$url" target = "_blank">Link zu Google Maps</a>\r\n\r\n'
        'Andere Aliasnamen für diesen Ort: $aliasNames\r\n\r\n'
        'TSV (Tabulator Separated Values) für Excel import:\r\n${tsvEntryParts.join('  ')}';

    body = '$body\r\n\r\n'
        'UUID: ${sha1.convert(utf8.encode('$body ${DateTime.now().microsecondsSinceEpoch}')).toString()}';

    Event e = Event(
        summary: address,
        description: body,
        start: EventDateTime(date: start),
        end: EventDateTime(date: end));
    return e;
  }

  /// send event with calendar api
  Future<Event> addEvent(Event event) async {
    String id = await RecourceLoader.defaultCalendarId();
    CalendarApi api = await RecourceLoader.calendarApiFromCredentials();
    Event send = await api.events.insert(event, id);
    return send;
  }
}
