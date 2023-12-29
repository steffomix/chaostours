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

import 'package:flutter_background_service/flutter_background_service.dart';

///
import 'package:chaostours/shared/shared_trackpoint_alias.dart';
import 'package:chaostours/shared/shared_trackpoint_task.dart';
import 'package:chaostours/shared/shared_trackpoint_user.dart';
import 'package:chaostours/channel/tracking.dart';
import 'package:chaostours/channel/background_channel.dart';
import 'package:chaostours/conf/app_user_settings.dart';
import 'package:chaostours/database/cache.dart';
import 'package:chaostours/database/type_adapter.dart';
import 'package:chaostours/event_manager.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/model/model_alias.dart';
import 'package:chaostours/model/model_user.dart';
import 'package:chaostours/model/model_task.dart';

typedef Callback = void Function();

enum DataChannelKey {
  tick,
  gps,
  gpsPoints,
  gpsSmoothPoints,
  gpsCalcPoints,
  gpsLastStatusChange,
  gpsLastStatusStanding,
  gpsLastStatusMoving,
  trackingStatus,
  statusDuration,
  lastAddress,
  lastFullAddress;
}

abstract class ChannelAsset {
  String? get sortOrder;
}

class ChannelAlias {
  final int distance;
  final int id;
  final ModelAlias model;
  final SharedTrackpointAlias shared;

  ChannelAlias(
      {required this.id,
      required this.model,
      required this.shared,
      required this.distance});
}

class ChannelUser implements ChannelAsset {
  final int id;
  final ModelUser model;
  final SharedTrackpointUser shared;

  ChannelUser({required this.id, required this.model, required this.shared});

  @override
  String get sortOrder => model.sortOrder;
}

class ChannelTask implements ChannelAsset {
  final int id;
  final ModelTask model;
  final SharedTrackpointTask shared;

  ChannelTask({required this.id, required this.model, required this.shared});

  @override
  String get sortOrder => model.sortOrder;
}

class DataChannel {
  static final Logger logger = Logger.logger<DataChannel>();
  static DataChannel? _instance;
  factory DataChannel() => _instance ??= DataChannel._();
  bool _initialized = false;
  bool get initalized => _initialized;
  int tick = 0;
  GPS? gps;
  List<GPS> gpsPoints = [];
  List<GPS> gpsSmoothPoints = [];
  List<GPS> gpsCalcPoints = [];
  GPS? gpsLastStatusChange;
  GPS? gpsLastStatusStanding;
  GPS? gpsLastStatusMoving;

  /// computed values
  TrackingStatus trackingStatus = TrackingStatus.standing;

  TrackingStatus trackingStatusTrigger = TrackingStatus.none;

  int distanceMoving = 0;
  int distanceStanding = 0;

  int get distance => trackingStatus == TrackingStatus.standing
      ? distanceStanding
      : distanceMoving;

  Duration _duration = Duration.zero;
  Duration get duration => _duration;

  int distanceTreshold = 0; // meter
  Duration durationTreshold = Duration.zero;

  String address = '';
  String fullAddress = '';

  List<ChannelAlias> aliasList = [];
  List<ChannelUser> userList = [];
  List<ChannelTask> taskList = [];

  String notes = '';

  Future<String> setTrackpointNotes(String text) async {
    return (notes =
        await Cache.backgroundTrackPointUserNotes.save<String>(text));
  }

  DataChannel._() {
    if (_instance == null) {
      Future.microtask(() async {
        await for (var data in FlutterBackgroundService()
            .on(BackgroundChannelCommand.onTracking.toString())) {
          _initialized = true;
          tick++;
          Cache.reload();
          try {
            /// serialized values
            gps = TypeAdapter.deserializeGps(
                data?[DataChannelKey.gps.toString()]);
            gpsPoints = TypeAdapter.deserializeGpsList(
                stringify(data?[DataChannelKey.gpsPoints.toString()] ?? []));
            gpsSmoothPoints = TypeAdapter.deserializeGpsList(stringify(
                data?[DataChannelKey.gpsSmoothPoints.toString()] ?? []));
            gpsCalcPoints = TypeAdapter.deserializeGpsList(stringify(
                data?[DataChannelKey.gpsCalcPoints.toString()] ?? []));
            gpsLastStatusChange = TypeAdapter.deserializeGps(
                data?[DataChannelKey.gpsLastStatusChange.toString()]);
            gpsLastStatusStanding = TypeAdapter.deserializeGps(
                data?[DataChannelKey.gpsLastStatusStanding.toString()]);
            gpsLastStatusMoving = TypeAdapter.deserializeGps(
                data?[DataChannelKey.gpsLastStatusMoving.toString()]);
            final oldTrackingStatus = trackingStatus;
            trackingStatus = TypeAdapter.deserializeTrackingStatus(
                    data?[DataChannelKey.trackingStatus.toString()]) ??
                TrackingStatus.standing;

            /// conditioned string values
            final addr = data?[DataChannelKey.lastAddress.toString()] ?? '';
            if (addr.isNotEmpty) {
              address = addr;
            } else {
              final cachedAddr =
                  await Cache.addressTimeLastLookup.load<String>('');
              if (cachedAddr.isNotEmpty) {
                address =
                    'Most Recent: ${await Cache.AddressMostRecent.load<String>('-')}';
              }

              /// load from cache?
            }
            final fullAddr =
                data?[DataChannelKey.lastFullAddress.toString()] ?? '';
            if (fullAddr.isNotEmpty) {
              fullAddress = fullAddr;
            }

            /// Cached values
            trackingStatusTrigger = await Cache.trackingStatusTriggered
                .load<TrackingStatus>(TrackingStatus.standing);
            notes = await Cache.backgroundTrackPointUserNotes.load<String>('');

            /// computed values
            _duration =
                gpsLastStatusChange?.time.difference(DateTime.now()).abs() ??
                    Duration.zero;

            distanceMoving = gpsPoints.isNotEmpty
                ? GPS.distanceOverTrackList(gpsPoints).round()
                : 0;
            distanceStanding = gpsLastStatusStanding != null &&
                    gpsPoints.isNotEmpty
                ? GPS.distance(gpsLastStatusStanding!, gpsPoints.first).round()
                : 0;
            Cache cache = Cache.appSettingDistanceTreshold;
            distanceTreshold = await cache
                .load<int>(AppUserSetting(cache).defaultValue as int);

            await updateAliasList();
            await updateUserList();
            await updateTaskList();

            /// fire events
            EventManager.fire<DataChannel>(_instance!);

            if (oldTrackingStatus != trackingStatus) {
              EventManager.fire<TrackingStatus>(trackingStatus);
            }

            logger.log('Datachannel finished');
          } catch (e, stk) {
            logger.error('Deserialize Channel Data: $e', stk);
          }
        }
      });
    }
  }

  List<String> stringify(List<dynamic> source) {
    List<String> cast = [];
    for (var dyn in source) {
      cast.add(dyn.toString());
    }
    return cast;
  }

  void sortUser() {
    userList.sort((modelA, modelB) {
      final a = modelA.model.sortOrder;
      final b = modelB.model.sortOrder;
      int result;
      if (a.isEmpty && b.isEmpty) {
        result = 0;
      } else if (a.isEmpty) {
        result = 1;
      } else if (b.isEmpty) {
        result = -1;
      } else {
        // Ascending Order
        result = a.compareTo(b);
      }
      return result;
    });
  }

  void sortTask() {
    taskList.sort((modelA, modelB) {
      final a = modelA.model.sortOrder;
      final b = modelB.model.sortOrder;
      int result;
      if (a.isEmpty) {
        result = 1;
      } else if (b.isEmpty) {
        result = -1;
      } else {
        // Ascending Order
        result = a.compareTo(b);
      }
      return result;
    });
  }

  Future<void> updateAssets() async {
    await updateAliasList();
    await updateUserList();
    await updateTaskList();
  }

  Future<void> updateAliasList() async {
    /// load ids from shared and database
    final sharedAliasList = await Cache.backgroundSharedAliasList
        .load<List<SharedTrackpointAlias>>([]);
    final modelAliasList = await ModelAlias.byIdList(sharedAliasList
        .map(
          (e) => e.id,
        )
        .toList());
    List<ChannelAlias> list = [];
    final g = gps ?? await GPS.gps();
    for (var shared in sharedAliasList) {
      ModelAlias model;
      try {
        model = modelAliasList.firstWhere((model) => model.id == shared.id);
      } catch (e) {
        continue;
      }
      int distance = GPS.distance(g, model.gps).round();
      try {
        list.add(ChannelAlias(
            id: shared.id,
            model: modelAliasList.firstWhere((model) => model.id == shared.id),
            shared: shared,
            distance: distance));
      } catch (e) {
        /// ignore and skip element
      }
    }
    aliasList = list;
  }

  Future<void> updateUserList() async {
    /// load ids from shared and database
    final sharedUserList = await Cache.backgroundSharedUserList
        .load<List<SharedTrackpointUser>>([]);
    final modelUserList = await ModelUser.byIdList(sharedUserList
        .map(
          (e) => e.id,
        )
        .toList());
    List<ChannelUser> list = [];
    for (var shared in sharedUserList) {
      try {
        list.add(ChannelUser(
            id: shared.id,
            model: modelUserList.firstWhere((model) => model.id == shared.id),
            shared: shared));
      } catch (e) {
        /// ignore and skip element
      }
    }
    userList = list;
  }

  Future<void> updateTaskList() async {
    /// load ids from shared and database
    final sharedTaskList = await Cache.backgroundSharedTaskList
        .load<List<SharedTrackpointTask>>([]);
    final modelTaskList = await ModelTask.byIdList(sharedTaskList
        .map(
          (e) => e.id,
        )
        .toList());
    List<ChannelTask> list = [];
    for (var shared in sharedTaskList) {
      try {
        list.add(ChannelTask(
            id: shared.id,
            model: modelTaskList.firstWhere((model) => model.id == shared.id),
            shared: shared));
      } catch (e) {
        /// ignore and skip element
      }
    }
    taskList = list;
  }
}
