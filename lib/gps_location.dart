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

import 'package:chaostours/model/model_location_group.dart';
import 'package:chaostours/model/model_trackpoint_calendar.dart';
import 'package:device_calendar/device_calendar.dart';

import 'package:flutter_native_timezone/flutter_native_timezone.dart';
import 'dart:math' as math;

///
import 'package:chaostours/channel/notification_channel.dart';
import 'package:chaostours/model/model_task.dart';
import 'package:chaostours/model/model_user.dart';
import 'package:chaostours/shared/shared_trackpoint_location.dart';
import 'package:chaostours/shared/shared_trackpoint_task.dart';
import 'package:chaostours/shared/shared_trackpoint_user.dart';
import 'package:chaostours/address.dart';
import 'package:chaostours/calendar.dart';
import 'package:chaostours/channel/data_channel.dart';
import 'package:chaostours/database/cache.dart';
import 'package:chaostours/conf/app_user_settings.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/model/model_location.dart';
import 'package:chaostours/model/model_trackpoint.dart';
import 'package:chaostours/channel/tracking.dart';
import 'package:chaostours/util.dart' as util;

class CalendarEvent {
  final Event event;
  final ModelLocationGroup modelGroup;

  CalendarEvent({required this.event, required this.modelGroup});
}

//
class GpsLocation {
  static final Logger logger = Logger.logger<GpsLocation>();

  final GPS gpsOfLocation;
  Address? address;
  LocationPrivacy get privacy => _privacy ?? LocationPrivacy.none;
  LocationPrivacy? _privacy;
  int radius = 0;

  final tracker = Tracker();
  final channel = DataChannel();
  final appCalendar = AppCalendar();
  final List<ModelLocation> locationModels;

  GpsLocation._location(
      {required this.gpsOfLocation, required this.locationModels});

  static Future<GpsLocation> gpsLocation(GPS gps,
      [bool updateSharedLocations = false]) async {
    List<ModelLocation> allModels = await ModelLocation.byArea(
        gps: gps,
        isActive: true,
        gpsArea: math.max(
            10000,
            await Cache.appSettingDistanceTreshold.load(
                AppUserSetting(Cache.appSettingDistanceTreshold).defaultValue
                    as int)));

    LocationPrivacy? priv;
    List<ModelLocation> models = [];
    int rad = 0;
    for (var model in allModels) {
      if (model.privacy.level >= LocationPrivacy.restricted.level) {
        continue;
      }
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

    final location = GpsLocation._location(
      gpsOfLocation: models.isEmpty ? gps : models.first.gps,
      locationModels: models,
    );

    location._privacy = priv;
    location.radius = rad;
    if (updateSharedLocations) {
      await Cache.backgroundSharedLocationList
          .save<List<SharedTrackpointLocation>>(location.locationModels
              .map((model) => SharedTrackpointLocation(id: model.id, notes: ''))
              .toList());
    }

    return location;
  }

  Future<ModelTrackPoint> createTrackPoint() async {
    address ??= await Address(gpsOfLocation)
        .lookup(OsmLookupConditions.onStatusChanged, saveToCache: true);
    return await ModelTrackPoint(
            gps: gpsOfLocation,
            timeStart: gpsOfLocation.time,
            timeEnd: DateTime.now(),
            calendarEventIds: await Cache.backgroundCalendarLastEventIds
                .load<List<CalendarEventId>>([]),
            address: address?.address ?? '',
            notes: await Cache.backgroundTrackPointNotes.load<String>(''))
        .addSharedAssets(this);
  }

  Future<GpsLocation> autocreateLocation() async {
    /// get address
    tracker.address = await Address(gpsOfLocation)
        .lookup(OsmLookupConditions.onAutoCreateLocation, saveToCache: true);

    var cache = Cache.appSettingDefaultLocationPrivacy;
    LocationPrivacy privacy = await cache.load<LocationPrivacy>(
        AppUserSetting(cache).defaultValue as LocationPrivacy);

    cache = Cache.appSettingDefaultLocationRadius;
    int defaultRadius =
        await cache.load<int>(AppUserSetting(cache).defaultValue as int);

    /// create location
    ModelLocation newModel = ModelLocation(
        gps: gpsOfLocation,
        title: tracker.address?.address ?? '',
        description: tracker.address?.addressDetails ?? '',
        privacy: privacy,
        radius: defaultRadius);

    await newModel.insert();
    final newLocation = await gpsLocation(gpsOfLocation, true);
    return newLocation;
  }

  bool _standingExecuted = false;
  Future<void> executeStatusStanding() async {
    if (_standingExecuted || privacy == LocationPrivacy.none) {
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
    if (_movingExecuted || privacy == LocationPrivacy.none) {
      return;
    }

    try {
      await _notifyMoving();
      ModelTrackPoint? tp = await _recordMoving();
      await _publishMoving(tp);

      tp?.calendarEventIds.clear();
      await Cache.backgroundCalendarLastEventIds
          .save<List<CalendarEventId>>([]);

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
    if (privacy.level <= LocationPrivacy.privat.level) {
      tracker.address = await Address(gpsOfLocation)
          .lookup(OsmLookupConditions.onStatusChanged, saveToCache: true);
    }
    // check privacy
    if (privacy.level > LocationPrivacy.restricted.level) {
      return;
    }

    NotificationChannel.sendTrackingUpdateNotification(
        title: 'Tick Update',
        message: 'New Status: ${tracker.trackingStatus?.name.toUpperCase()}'
            '${tracker.address != null ? '\n${tracker.address?.address}' : ''}',
        details: NotificationChannel.trackingStatusChangedConfiguration);
  }

  Future<void> _recordStanding() async {
    // check privacy
    if (privacy.level > LocationPrivacy.privat.level) {
      return;
    }

    tracker.address = await Address(gpsOfLocation)
        .lookup(OsmLookupConditions.onStatusChanged, saveToCache: true);

    // update last visited
    for (var model in locationModels) {
      model.lastVisited = gpsOfLocation.time;
      await model.update();
    }
  }

  Future<List<CalendarEvent>> composeCalendarEvents() async {
    if (locationModels.isEmpty) {
      return [];
    }

    // grab recources
    final calendarIds = await mergeCalendarEvents();
    final trackpoint = await createTrackPoint();

    // grab location models
    final mainLocation = locationModels.first;
    final nearbyLocation = <ModelLocation>[];
    if (locationModels.length > 1) {
      nearbyLocation.addAll(locationModels.getRange(1, locationModels.length));
    }

    final tzLocation =
        getLocation(await FlutterNativeTimezone.getLocalTimezone());
    final timeStart = TZDateTime.from(trackpoint.timeStart, tzLocation);
    final timeEnd = TZDateTime.from(trackpoint.timeEnd, tzLocation);

    List<CalendarEvent> events = [];
    for (var calendar in calendarIds) {
      final ModelLocationGroup? group =
          await ModelLocationGroup.byId(calendar.locationGroupId);
      if (group == null) {
        continue;
      }

      String eventTitle =
          group.calendarLocation ? mainLocation.title : '#${mainLocation.id}';

      List<String> bodyParts = [];

      if (!group.calendarAllDay) {
        // time start
        if (group.calendarTimeStart) {
          bodyParts.add(
              '[START]: ${util.formatDateTime(trackpoint.timeStart)}<br />');
        }
        // time end
        if (group.calendarTimeEnd) {
          bodyParts.add(
              '[END]: ${util.formatDateTime(group.calendarAllDay ? trackpoint.timeStart : trackpoint.timeEnd)}<br />');
        }
        // duration
        if (group.calendarDuration) {
          bodyParts.add(
              '[DURATION]: ${util.formatDuration(trackpoint.duration)}<br /><br />');
        }
      } else {
        bodyParts.add('[DURATION]: all day<br /><br />');
      }
      // GPS
      if (group.calendarGps) {
        bodyParts.add('[GPS]: ');
        if (group.calendarHtml) {
          bodyParts.add(
              '<a href="https://maps.google.com?q=${trackpoint.gps.lat},${trackpoint.gps.lon}">maps.google.com?q=${trackpoint.gps.lat},${trackpoint.gps.lon}</a><br /><br />');
        } else {
          bodyParts
              .add('${trackpoint.gps.lat},${trackpoint.gps.lon}<br /><br />');
        }
      }
      // trackpoint notes
      if (group.calendarTrackpointNotes) {
        bodyParts.add('[NOTES]:<br />${trackpoint.notes.trim()}<br /><br />');
      }

      // main location
      if (group.calendarLocation || group.calendarLocationDescription) {
        bodyParts.add('[MAIN LOCATION #${mainLocation.id}]:<br />');
        if (group.calendarLocation) {
          bodyParts.add(
              '${GPS.distance(trackpoint.gps, mainLocation.gps).round()}m: ${mainLocation.title.trim()}${group.calendarLocationDescription ? '<br />' : '<br /><br />'}');
        }
        if (group.calendarLocationDescription) {
          bodyParts.add('${mainLocation.description.trim()}<br /><br />');
        }
      }

      if (group.calendarLocationNearby ||
          group.calendarNearbyLocationDescription) {
        for (var location in nearbyLocation) {
          bodyParts.add('[NEARBY LOCATION #${location.id}]:<br />');
          if (group.calendarLocation) {
            bodyParts.add(
                '${GPS.distance(trackpoint.gps, location.gps).round()}m: ${location.title.trim()}${group.calendarNearbyLocationDescription ? '<br />' : '<br /><br />'}');
          }
          if (group.calendarNearbyLocationDescription) {
            bodyParts.add('${location.description.trim()}<br /><br />');
          }
        }
      }

      if (group.calendarAddress) {
        bodyParts.add('[ADDRESS]: ${trackpoint.address.trim()}<br /><br />');
      }

      if (group.calendarFullAddress) {
        bodyParts.add(
            '[FULL ADDRESS]:<br />${trackpoint.fullAddress.trim()}<br /><br />');
      }

      // tasks
      if (group.calendarTasks ||
          group.calendarTaskDescription ||
          group.calendarTaskNotes) {
        for (var task in trackpoint.taskModels) {
          bodyParts.add('[TASK #${task.id}]:<br />');
          if (group.calendarTasks) {
            bodyParts.add(
                '${task.title.trim()}${group.calendarTaskDescription || group.calendarTaskNotes ? '<br />' : '<br /><br />'}');
          }
          if (group.calendarTaskDescription) {
            bodyParts.add(
                '${task.description.trim()}${group.calendarTaskNotes ? '<br />' : '<br /><br />'}');
          }
          if (group.calendarTaskNotes) {
            bodyParts.add('${task.notes.trim()}<br /><br />');
          }
        }
      }

      // users
      if (group.calendarUsers ||
          group.calendarUserDescription ||
          group.calendarUserNotes) {
        for (var user in trackpoint.userModels) {
          bodyParts.add('[USER #${user.id}]:<br />');
          if (group.calendarUsers) {
            bodyParts.add(
                '${user.title.trim()}${group.calendarUserDescription || group.calendarUserNotes ? '<br />' : '<br /><br />'}');
          }
          if (group.calendarUserDescription) {
            bodyParts.add(
                '${user.description.trim()}${group.calendarUserNotes ? '<br />' : '<br /><br />'}');
          }
          if (group.calendarUserNotes) {
            bodyParts.add('${user.notes.trim()}<br /><br />');
          }
        }
      }

      bodyParts.add('This message was generated by Chaos Tours.');

      final body = bodyParts.join('');

      var event = Event(calendar.calendarId,
          eventId: calendar.eventId.isEmpty ? null : calendar.eventId,
          title: eventTitle,
          start: timeStart,
          end: group.calendarAllDay ? timeStart : timeEnd,
          location: group.calendarGps
              ? '${trackpoint.gps.lat},${trackpoint.gps.lon}'
              : null,
          url: group.calendarHtml && group.calendarGps
              ? Uri.parse(
                  'https://maps.google.com?q=${trackpoint.gps.lat},${trackpoint.gps.lon}')
              : null,
          allDay: group.calendarAllDay ? true : false,
          description: body);

      events.add(CalendarEvent(event: event, modelGroup: group));
    }

    return events;
  }

  Future<void> _publishStanding() async {
    if (await Cache.databaseImportedCalendarDisabled.load<bool>(false)) {
      return;
    }
    // check privacy
    if (privacy.level > LocationPrivacy.public.level) {
      return;
    }

    bool publishActivated = await Cache.appSettingPublishToCalendar.load<bool>(
        AppUserSetting(Cache.appSettingPublishToCalendar).defaultValue as bool);
    if (!publishActivated) {
      return;
    }

    final events = await composeCalendarEvents();
    List<CalendarEventId> sharedEvents = [];
    for (var event in events) {
      final calendar = await AppCalendar().calendarById(event.event.calendarId);
      if (calendar != null) {
        var eventId = await AppCalendar().inserOrUpdate(event.event);
        sharedEvents.add(CalendarEventId(
            locationGroupId: event.modelGroup.id,
            calendarId: calendar.id ?? '',
            eventId: eventId ?? ''));

        await ModelTrackpointCalendar(
                idTrackPoint: 0,
                idLocationGroup: event.modelGroup.id,
                idCalendar: event.event.calendarId ?? '',
                idEvent: event.event.eventId ?? '',
                title: event.event.title ?? '',
                body: event.event.description ?? '')
            .insertOrUpdate();
      }
    }

    await Cache.backgroundCalendarLastEventIds
        .save<List<CalendarEventId>>(sharedEvents);
  }

  Future<void> _notifyMoving() async {
    // check privacy
    if (privacy.level > LocationPrivacy.restricted.level) {
      return;
    }
  }

  Future<ModelTrackPoint?> _recordMoving() async {
    // check privacy
    if (privacy.level > LocationPrivacy.privat.level) {
      return null;
    }

    // check if location is required and present
    bool locationRequired =
        await Cache.appSettingStatusStandingRequireLocation.load<bool>(true);
    if (locationRequired && locationModels.isEmpty) {
      return null;
    }

    final Address address = await Address(gpsOfLocation)
        .lookup(OsmLookupConditions.onStatusChanged, saveToCache: true);
    ModelTrackPoint newTrackPoint = ModelTrackPoint(
        gps: gpsOfLocation,
        timeStart: gpsOfLocation.time,
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

  Future<bool> publishToCalendars(ModelTrackPoint tp) async =>
      await _publishMoving(tp);

  // finish standing event
  Future<bool> _publishMoving(ModelTrackPoint? tp) async {
    if (tp == null) {
      return false;
    }
    if (privacy.level > LocationPrivacy.public.level) {
      return false;
    }
    if (await Cache.databaseImportedCalendarDisabled.load<bool>(false)) {
      return false;
    }

    bool publishActivated = await Cache.appSettingPublishToCalendar.load<bool>(
        AppUserSetting(Cache.appSettingPublishToCalendar).defaultValue as bool);
    if (!publishActivated) {
      return false;
    }

    List<CalendarEventId> sharedCalendars = await mergeCalendarEvents();
    if (sharedCalendars.isEmpty) {
      return false;
    }

    final events = await composeCalendarEvents();
    for (var event in events) {
      final calendar = await AppCalendar().calendarById(event.event.calendarId);
      if (calendar != null) {
        String? eventId = await AppCalendar().inserOrUpdate(event.event);
        await ModelTrackpointCalendar(
                idTrackPoint: tp.id,
                idLocationGroup: event.modelGroup.id,
                idCalendar: event.event.calendarId ?? '',
                idEvent: eventId ?? '',
                title: event.event.title ?? '',
                body: event.event.description ?? '')
            .insertOrUpdate();
      }
    }
    return true;
  }

  Future<List<CalendarEventId>> mergeCalendarEvents() async {
    if (privacy.level > LocationPrivacy.public.level) {
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

    final dbCalendarList = await ModelLocation.calendarIds(locationModels);

    List<CalendarEventId> result = [...sharedCalendarList];
    for (var id in dbCalendarList) {
      if (!sharedContains(id)) {
        result.add(id);
      }
    }
    return result;
  }
}
