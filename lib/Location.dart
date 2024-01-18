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

import 'package:chaostours/model/model_alias_group.dart';
import 'package:device_calendar/device_calendar.dart';

import 'package:flutter_native_timezone/flutter_native_timezone.dart';
import 'package:timezone/timezone.dart';
import 'dart:math' as math;

///
import 'package:chaostours/channel/notification_channel.dart';
import 'package:chaostours/database/database.dart';
import 'package:chaostours/model/model_task.dart';
import 'package:chaostours/model/model_user.dart';
import 'package:chaostours/shared/shared_trackpoint_alias.dart';
import 'package:chaostours/shared/shared_trackpoint_task.dart';
import 'package:chaostours/shared/shared_trackpoint_user.dart';
import 'package:chaostours/address.dart';
import 'package:chaostours/calendar.dart';
import 'package:chaostours/channel/data_channel.dart';
import 'package:chaostours/database/cache.dart';
import 'package:chaostours/conf/app_user_settings.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/model/model_alias.dart';
import 'package:chaostours/model/model_trackpoint.dart';
import 'package:chaostours/channel/tracking.dart';
import 'package:chaostours/util.dart' as util;

class Location {
  static final Logger logger = Logger.logger<Location>();

  final GPS gps;
  Address? address;
  AliasPrivacy get privacy => _privacy ?? AliasPrivacy.none;
  AliasPrivacy? _privacy;
  int radius = 0;

  final tracker = Tracker();
  final channel = DataChannel();
  final appCalendar = AppCalendar();
  final List<ModelAlias> aliasModels;

  Location._location({required this.gps, required this.aliasModels});

  static Future<Location> location(GPS gps) async {
    List<ModelAlias> allModels = await ModelAlias.byArea(
        gps: gps,
        gpsArea: math.max(
            1000,
            await Cache.appSettingDistanceTreshold.load(
                AppUserSetting(Cache.appSettingDistanceTreshold).defaultValue
                    as int)));

    AliasPrivacy? priv;
    List<ModelAlias> models = [];
    int rad = 0;
    for (var model in allModels) {
      if (GPS.distance(gps, model.gps) <= model.radius) {
        model.sortDistance = model.radius;
        models.add(model);
        rad = math.max(rad, model.radius);
        priv ??= model.privacy;
        if (model.privacy.level > priv.level) {
          priv = model.privacy;
        }
      }
    }
    models.sort((a, b) => a.sortDistance.compareTo(b.sortDistance));
    if (rad == 0) {
      rad =
          AppUserSetting(Cache.appSettingDistanceTreshold).defaultValue as int;
    }

    final location = Location._location(
      gps: gps,
      aliasModels: models,
    );

    location._privacy = priv;
    location.radius = rad;
    await location.updateSharedAliasList();
    return location;
  }

  Future<ModelTrackPoint> createTrackPoint() async {
    address ??= await Address(gps)
        .lookup(OsmLookupConditions.onStatusChanged, saveToCache: true);
    return await ModelTrackPoint(
            gps: gps,
            timeStart:
                (await Cache.backgroundGpsStartStanding.load<GPS>(gps)).time,
            timeEnd: gps.time,
            calendarEventIds: await Cache.backgroundCalendarLastEventIds
                .load<List<CalendarEventId>>([]),
            address: address?.address ?? '',
            notes: await Cache.backgroundTrackPointNotes.load<String>(''))
        .addSharedAssets(this);
  }

  Future<void> updateSharedAliasList() async {
    List<SharedTrackpointAlias> oldShared = await Cache
        .backgroundSharedAliasList
        .load<List<SharedTrackpointAlias>>([]);
    List<SharedTrackpointAlias> newShared = [];
    for (var model in aliasModels) {
      newShared.add(oldShared
              .where(
                (old) => old.id == model.id,
              )
              .firstOrNull ??
          SharedTrackpointAlias(id: model.id, notes: ''));
    }

    await Cache.backgroundSharedAliasList
        .save<List<SharedTrackpointAlias>>(newShared);
  }

  Future<Location> autocreateAlias() async {
    /// get address
    tracker.address = await Address(gps)
        .lookup(OsmLookupConditions.onAutoCreateAlias, saveToCache: true);

    /// create alias
    ModelAlias newAlias = ModelAlias(
        gps: gps,
        lastVisited: tracker.gpsCalcPoints.lastOrNull?.time ?? gps.time,
        timesVisited: 1,
        title: tracker.address?.address ?? '',
        description: tracker.address?.addressDetails ?? '',
        radius: radius);

    await newAlias.insert();
    final newLocation = await location(gps);
    await newLocation.updateSharedAliasList();
    return newLocation;
  }

  bool _standingExecuted = false;
  Future<void> executeStatusStanding() async {
    if (_standingExecuted || _privacy == AliasPrivacy.none) {
      return;
    }
    try {
      await _notifyStanding();
      await _recordStanding();
      await _publishStanding();
    } catch (e, stk) {
      logger.error('executeStatusStanding: $e', stk);
    }
    _standingExecuted = true;
  }

  bool _movingExecuted = false;
  Future<void> executeStatusMoving() async {
    if (_movingExecuted || _privacy == AliasPrivacy.none) {
      return;
    }

    try {
      await _notifyMoving();
      ModelTrackPoint? tp = await _recordMoving();
      await _publishMoving(tp);

      // reset notes
      await Cache.backgroundTrackPointNotes.save<String>('');
      // reset tasks with preselected
      await Cache.backgroundSharedTaskList
          .save<List<SharedTrackpointTask>>((await ModelTask.preselected())
              .map(
                (e) => SharedTrackpointTask(id: e.id, notes: ''),
              )
              .toList());
      // reset users with preselected
      await Cache.backgroundSharedUserList
          .save<List<SharedTrackpointUser>>((await ModelUser.preselected())
              .map(
                (e) => SharedTrackpointUser(id: e.id, notes: ''),
              )
              .toList());
    } catch (e, stk) {
      logger.error('executeStatusMoving: $e', stk);
    }
    _movingExecuted = true;
  }

  Future<void> _notifyStanding() async {
    // update address
    if (privacy.level <= AliasPrivacy.privat.level) {
      tracker.address = await Address(gps)
          .lookup(OsmLookupConditions.onStatusChanged, saveToCache: true);
    }
    // check privacy
    if (privacy.level > AliasPrivacy.restricted.level) {
      return;
    }

    await updateSharedAliasList();

    NotificationChannel.sendTrackingUpdateNotification(
        title: 'Tick Update',
        message: 'New Status: ${tracker.trackingStatus?.name.toUpperCase()}'
            '${tracker.address != null ? '\n${tracker.address?.address}' : ''}',
        details: NotificationChannel.trackingStatusChangedConfiguration);
  }

  Future<void> _recordStanding() async {
    // check privacy
    if (privacy.level > AliasPrivacy.privat.level) {
      return;
    }
    tracker.address = await Address(tracker.gpsLastStatusStanding ?? gps)
        .lookup(OsmLookupConditions.onStatusChanged, saveToCache: true);

    // update last visited
    for (var model in aliasModels) {
      model.lastVisited =
          (await Cache.backgroundGpsStartStanding.load<GPS>(gps)).time;
      await model.update();
    }
  }

  Future<List<Event>> composeCalendarEvents() async {
    if (aliasModels.isEmpty) {
      return [];
    }

    // grab recources
    final calendarIds = await mergeCalendarEvents();
    final trackpoint = await createTrackPoint();

    // grab alias models
    final mainAlias = aliasModels.first;
    final nearbyAlias = <ModelAlias>[];
    if (aliasModels.length > 1) {
      nearbyAlias.addAll(aliasModels.getRange(1, aliasModels.length));
    }

    final tzLocation =
        getLocation(await FlutterNativeTimezone.getLocalTimezone());
    final timeStart = TZDateTime.from(trackpoint.timeStart, tzLocation);
    final timeEnd = TZDateTime.from(trackpoint.timeEnd, tzLocation);

    List<Event> events = [];
    for (var calendar in calendarIds) {
      final ModelAliasGroup? group =
          await ModelAliasGroup.byId(calendar.aliasGroupId);
      if (group == null) {
        continue;
      }

      if (!group.ensuredPrivacyCompliance) {
        continue;
      }

      String eventTitle =
          group.calendarAlias ? mainAlias.title : '#${mainAlias.id}';

      List<String> bodyParts = [];

      // time start
      if (group.calendarTimeStart) {
        bodyParts
            .add('[START]: ${util.formatDateTime(trackpoint.timeStart)}\n');
      }
      // time end
      if (group.calendarTimeEnd) {
        bodyParts.add('[END]: ${util.formatDateTime(trackpoint.timeEnd)}\n');
      }
      // duration
      if (group.calendarDuration) {
        bodyParts
            .add('[DURATION]: ${util.formatDuration(trackpoint.duration)}\n\n');
      }
      // GPS
      if (group.calendarGps) {
        bodyParts.add('[GPS]: ');
        if (group.calendarHtml) {
          bodyParts.add(
              '<a href="https://maps.google.com?q=${trackpoint.gps.lat},${trackpoint.gps.lon}">[GPS]: maps.google.com?q=${trackpoint.gps.lat},${trackpoint.gps.lon}</a>\n\n');
        } else {
          bodyParts.add('${trackpoint.gps.lat},${trackpoint.gps.lon}\n\n');
        }
      }
      // trackpoint notes
      if (group.calendarTrackpointNotes) {
        bodyParts.add('[NOTES]:\n${trackpoint.notes.trim()}\n\n');
      }

      // main alias
      if (group.calendarAlias || group.calendarAliasDescription) {
        bodyParts.add('[MAIN LOCATION #${mainAlias.id}]:\n');
        if (group.calendarAlias) {
          bodyParts.add(
              '${GPS.distance(trackpoint.gps, mainAlias.gps).round()}m: ${mainAlias.title.trim()}${group.calendarAliasDescription ? '\n' : '\n\n'}');
        }
        if (group.calendarAliasDescription) {
          bodyParts.add('${mainAlias.description.trim()}\n\n');
        }
      }

      if (group.calendarAliasNearby || group.calendarNearbyAliasDescription) {
        for (var alias in nearbyAlias) {
          bodyParts.add('[NEARBY LOCATION #${alias.id}]:\n');
          if (group.calendarAlias) {
            bodyParts.add(
                '${GPS.distance(trackpoint.gps, alias.gps).round()}m: ${alias.title.trim()}${group.calendarNearbyAliasDescription ? '\n' : '\n\n'}');
          }
          if (group.calendarNearbyAliasDescription) {
            bodyParts.add('${alias.description.trim()}\n\n');
          }
        }
      }

      if (group.calendarAddress) {
        bodyParts.add('[ADDRESS]: ${trackpoint.address.trim()}\n\n');
      }

      if (group.calendarFullAddress) {
        bodyParts.add('[FULL ADDRESS]:\n${trackpoint.fullAddress.trim()}\n\n');
      }

      // tasks
      if (group.calendarTasks ||
          group.calendarTaskDescription ||
          group.calendarTaskNotes) {
        for (var task in trackpoint.taskModels) {
          bodyParts.add('[TASK #${task.id}]:\n');
          if (group.calendarTasks) {
            bodyParts.add(
                '${task.title.trim()}${group.calendarTaskDescription || group.calendarTaskNotes ? '\n' : '\n\n'}');
          }
          if (group.calendarTaskDescription) {
            bodyParts.add(
                '${task.description.trim()}${group.calendarTaskNotes ? '\n' : '\n\n'}');
          }
          if (group.calendarTaskNotes) {
            bodyParts.add('${task.notes.trim()}\n\n');
          }
        }
      }

      // users
      if (group.calendarUsers ||
          group.calendarUserDescription ||
          group.calendarUserNotes) {
        for (var user in trackpoint.userModels) {
          bodyParts.add('[USER #${user.id}]:\n');
          if (group.calendarUsers) {
            bodyParts.add(
                '${user.title.trim()}${group.calendarUserDescription || group.calendarUserNotes ? '\n' : '\n\n'}');
          }
          if (group.calendarUserDescription) {
            bodyParts.add(
                '${user.description.trim()}${group.calendarUserNotes ? '\n' : '\n\n'}');
          }
          if (group.calendarUserNotes) {
            bodyParts.add('${user.notes.trim()}\n\n');
          }
        }
      }

      bodyParts.add('This message was generated by Chaos Tours.');

      final body = bodyParts.join('');

      var event = Event(calendar.calendarId,
          title: eventTitle,
          start: timeStart,
          end: timeEnd,
          location: group.calendarGps
              ? '${trackpoint.gps.lat},${trackpoint.gps.lon}'
              : null,
          description: body);

      events.add(event);
    }

    return events;
  }

  Future<void> _publishStanding() async {
    if (await Cache.databaseImportedCalendarDisabled.load<bool>(false)) {
      return;
    }
    // check privacy
    if (privacy.level > AliasPrivacy.public.level) {
      return;
    }
    bool publishActivated = await Cache.appSettingPublishToCalendar.load<bool>(
        AppUserSetting(Cache.appSettingPublishToCalendar).defaultValue as bool);
    if (!publishActivated) {
      return;
    }
    var calendars = await appCalendar.loadCalendars();
    if (calendars.isEmpty) {
      return;
    }

    final calendarEvents = await mergeCalendarEvents();

    final tp = await createTrackPoint();
    final lastStatusChange =
        await Cache.backgroundGpsLastStatusChange.load<GPS>(tp.gps);

    final start = TZDateTime.from(tp.timeStart,
        getLocation(await FlutterNativeTimezone.getLocalTimezone()));
    const cache = Cache.appSettingTimeRangeTreshold;
    final end = start.add(Duration(
        seconds: (await cache
                .load<Duration>(AppUserSetting(cache).defaultValue as Duration))
            .inSeconds));
    final title =
        'Arrived ${tp.aliasModels.isNotEmpty ? tp.aliasModels.first.title : tp.address} - ${start.hour}.${start.minute}';
    final location =
        'maps.google.com?q=${lastStatusChange.lat},${lastStatusChange.lon}';
    final description =
        '${tp.aliasModels.isNotEmpty ? tp.aliasModels.first.title : tp.address}\n'
        '${start.day}.${start.month}.${start.year}\n'
        'at ${start.hour}.${start.minute} - unknown)\n\n'
        'Tasks: ...\n\n'
        'Users:\n${tp.userModels.map(
              (e) => e.title,
            ).join(', ')}\n\n'
        'Notes: ...';

    for (var calId in calendarEvents) {
      Calendar? calendar = await appCalendar.calendarById(calId.calendarId);
      if (calendar == null) {
        logger.warn('startCalendarEvent: no calendar #$calId found');
        continue;
      }
      final id = await appCalendar.inserOrUpdate(Event(calendar.id,
          title: title,
          start: start,
          end: end,
          location: location,
          description: description));

      calId.eventId = id ?? '';

      await Future.delayed(const Duration(milliseconds: 100));
    }

    /// cache event id
    await Cache.backgroundCalendarLastEventIds
        .save<List<CalendarEventId>>(calendarEvents);
  }

  Future<void> _notifyMoving() async {
    // check privacy
    if (privacy.level > AliasPrivacy.restricted.level) {
      return;
    }
  }

  Future<ModelTrackPoint?> _recordMoving() async {
    // check privacy
    if (privacy.level > AliasPrivacy.privat.level) {
      return null;
    }

    // check if alias is required and present
    bool aliasRequired =
        await Cache.appSettingStatusStandingRequireAlias.load<bool>(true);
    if (aliasRequired && aliasModels.isEmpty) {
      return null;
    }

    final Address address = await Address(gps)
        .lookup(OsmLookupConditions.onStatusChanged, saveToCache: true);
    ModelTrackPoint newTrackPoint = ModelTrackPoint(
        gps: gps,
        timeStart: gps.time,
        timeEnd: DateTime.now(),
        calendarEventIds: await Cache.backgroundCalendarLastEventIds
            .load<List<CalendarEventId>>([]),
        address: address.address,
        fullAddress: address.addressDetails,
        notes: await Cache.backgroundTrackPointNotes.load<String>(''));

    await newTrackPoint.addSharedAssets(this);

    /// save new TrackPoint with user- and task ids
    await newTrackPoint.insert();
    //_debugInsert(newTrackPoint);
    return newTrackPoint;
  }

  // finish standing event
  Future<void> _publishMoving(ModelTrackPoint? tp) async {
    if (await Cache.databaseImportedCalendarDisabled.load<bool>(false)) {
      return;
    }
    if (tp == null) {
      return;
    }
    if (privacy.level > AliasPrivacy.public.level) {
      return;
    }

    bool publishActivated = await Cache.appSettingPublishToCalendar.load<bool>(
        AppUserSetting(Cache.appSettingPublishToCalendar).defaultValue as bool);
    if (!publishActivated) {
      return;
    }

    List<CalendarEventId> sharedCalendars = await mergeCalendarEvents();
    if (sharedCalendars.isEmpty) {
      return;
    }

    GPS lastStatusChange =
        await Cache.backgroundGpsLastStatusChange.load<GPS>(tp.gps);

    final tzLocation =
        getLocation(await FlutterNativeTimezone.getLocalTimezone());
    var start = TZDateTime.from(tp.timeStart, tzLocation);
    var end = TZDateTime.from(tp.timeEnd, tzLocation);

    var title =
        '${tp.aliasModels.isNotEmpty ? tp.aliasModels.first.title : tp.address}; ${util.formatDuration(tp.duration)}';
    var location =
        'maps.google.com?q=${lastStatusChange.lat},${lastStatusChange.lon}';
    var description =
        '${tp.aliasModels.isNotEmpty ? tp.aliasModels.first.title : tp.address}\n'
        '${start.day}.${start.month}. - ${util.formatDuration(tp.duration)}\n'
        '(${start.hour}.${start.minute} - ${end.hour}.${end.minute})\n\n'
        'Tasks:\n${tp.taskModels.map(
              (e) => e.title,
            ).join(', ')}\n\n'
        'Users:\n${tp.userModels.map(
              (e) => e.title,
            ).join(', ')}\n\n'
        'Notes: ${tp.notes.isEmpty ? '-' : tp.notes}';

    for (CalendarEventId calId in sharedCalendars) {
      Calendar? calendar = await appCalendar.calendarById(calId.calendarId);
      if (calendar == null) {
        continue;
      }

      Event event = Event(calendar.id,
          eventId: calId.eventId.isEmpty ? null : calId.eventId,
          title: title,
          start: start,
          end: end,
          location: location,
          description: description);
      String? id = await appCalendar.inserOrUpdate(event);
      calId.eventId = id ?? '';
      // save for edit trackpoint
      await DB.execute(
        (txn) async {
          for (CalendarEventId calId in sharedCalendars) {
            await txn.insert(TableTrackPointCalendar.table, {
              TableTrackPointCalendar.idTrackPoint.column: tp.id,
              TableTrackPointCalendar.idAliasGroup.column: calId.aliasGroupId,
              TableTrackPointCalendar.idCalendar.column: calId.calendarId,
              TableTrackPointCalendar.idEvent.column: calId.eventId,
              TableTrackPointCalendar.title.column: title,
              TableTrackPointCalendar.body.column: description
            });
          }
        },
      );
    }

    // clear calendar cache
    await Cache.backgroundCalendarLastEventIds.save<List<CalendarEventId>>([]);
    tp.calendarEventIds.clear();
  }

  Future<List<CalendarEventId>> mergeCalendarEvents() async {
    if (privacy.level > AliasPrivacy.public.level) {
      return [];
    }
    final sharedCalendarList = await Cache.backgroundCalendarLastEventIds
        .load<List<CalendarEventId>>([]);

    bool sharedContains(CalendarEventId calendar) {
      for (var cal in sharedCalendarList) {
        if (cal.calendarId == calendar.calendarId) {
          return true;
        }
      }
      return false;
    }

    final dbCalendarList = await ModelAlias.calendarIds(aliasModels);

    List<CalendarEventId> result = [...sharedCalendarList];
    for (var id in dbCalendarList) {
      if (!sharedContains(id)) {
        result.add(id);
      }
    }
    return result;
  }
}
