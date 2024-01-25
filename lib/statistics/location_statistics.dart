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

import 'dart:collection';

///
import 'package:chaostours/database/database.dart';
import 'package:chaostours/database/type_adapter.dart';
import 'package:chaostours/model/model_group.dart';
import 'package:chaostours/statistics/asset_statistics.dart';

class LocationStatistics implements AssetStatistics {
  static const columnCount = 'ct';
  static const columnDurationTotal = 'durationTotal';
  static const columnDurationMin = 'durationMin';
  static const columnDurationMax = 'durationMax';
  static const columnDurationAverage = 'durationAverage';

  static const columnFirstVisited = 'tStart';
  static const columnLastVisited = 'tEnd';

  @override
  ModelGroup model;
  @override
  int count = 0;
  @override
  Duration durationTotal = Duration.zero;
  @override
  Duration durationMin = Duration.zero;
  @override
  Duration durationMax = Duration.zero;
  @override
  Duration durationAverage = Duration.zero;
  @override
  late DateTime firstVisited;
  @override
  late DateTime lastVisited;

  LocationStatistics({
    required this.model,
    this.count = 0,
    this.durationTotal = Duration.zero,
    this.durationMin = Duration.zero,
    this.durationMax = Duration.zero,
    this.durationAverage = Duration.zero,
    required DateTime tStart,
    required DateTime tEnd,
  }) {
    firstVisited = tStart;
    lastVisited = tEnd;
  }

  static Future<LocationStatistics> statistics(ModelGroup model,
      {DateTime? start, DateTime? end, bool isActive = true}) async {
    List<Object?> params = [model.id, TypeAdapter.serializeBool(isActive)];
    String whereStart = '';
    String whereEnd = '';
    if (start != null) {
      params.add(TypeAdapter.dbTimeToInt(start));
      whereStart = ' AND ${TableTrackPoint.timeStart.column} >= ? ';
    }
    if (end != null) {
      params.add(TypeAdapter.dbTimeToInt(end));
      whereEnd = ' AND ${TableTrackPoint.timeEnd.column} <= ? ';
    }
    final q = '''
    SELECT SUM(${TableTrackPoint.timeEnd.column} - ${TableTrackPoint.timeStart.column}) AS $columnDurationTotal,
      MIN(${TableTrackPoint.timeEnd.column} - ${TableTrackPoint.timeStart.column}) AS $columnDurationMin,
      MAX(${TableTrackPoint.timeEnd.column} - ${TableTrackPoint.timeStart.column}) AS $columnDurationMax,
      ROUND(AVG(${TableTrackPoint.timeEnd.column} - ${TableTrackPoint.timeStart.column})) AS $columnDurationAverage,
      MIN( ${TableTrackPoint.timeStart.column}) AS $columnFirstVisited,
      MAX( ${TableTrackPoint.timeStart.column}) AS $columnLastVisited,
      COUNT(*) AS $columnCount
    FROM ${TableTrackPointLocation.table}
    LEFT JOIN ${TableTrackPoint.table} ON ${TableTrackPoint.id} = ${TableTrackPointLocation.idTrackPoint}
    WHERE ${TableTrackPointLocation.idLocation} = ?
    AND (${TableTrackPoint.isActive} = ?) 
    $whereStart 
    $whereEnd
''';

    final rows = await DB.execute(
      (txn) async {
        return await txn.rawQuery(q, params);
      },
    );

    final map = rows.firstOrNull ?? {};

    return _fromMap(model, map);
  }

  static Future<LocationStatistics> groupStatistics(ModelGroup model,
      {DateTime? start, DateTime? end, bool isActive = true}) async {
    List<Object?> params = [model.id, TypeAdapter.serializeBool(isActive)];
    String whereStart = '';
    String whereEnd = '';
    if (start != null) {
      params.add(TypeAdapter.dbTimeToInt(start));
      whereStart = ' AND ${TableTrackPoint.timeStart.column} >= ? ';
    }
    if (end != null) {
      params.add(TypeAdapter.dbTimeToInt(end));
      whereEnd = ' AND ${TableTrackPoint.timeEnd.column} <= ? ';
    }

    final q =
        '''SELECT SUM(${TableTrackPoint.timeEnd.column} - ${TableTrackPoint.timeStart.column}) AS $columnDurationTotal,
      MIN(${TableTrackPoint.timeEnd.column} - ${TableTrackPoint.timeStart.column}) AS $columnDurationMin,
      MAX(${TableTrackPoint.timeEnd.column} - ${TableTrackPoint.timeStart.column}) AS $columnDurationMax,
      ROUND(AVG(${TableTrackPoint.timeEnd.column} - ${TableTrackPoint.timeStart.column})) AS $columnDurationAverage,
      MIN( ${TableTrackPoint.timeStart.column}) AS $columnFirstVisited,
      MAX( ${TableTrackPoint.timeStart.column}) AS $columnLastVisited,
      COUNT(*) AS $columnCount
    FROM ${TableTrackPointLocation.table}
    LEFT JOIN ${TableLocationLocationGroup.table} ON ${TableLocationLocationGroup.idLocation} = ${TableTrackPointLocation.idLocation}
    LEFT JOIN ${TableTrackPoint.table} ON ${TableTrackPoint.id} = ${TableTrackPointLocation.idTrackPoint}
    WHERE ${TableLocationLocationGroup.idLocationGroup} = ?
    AND (${TableTrackPoint.isActive} = ?) 
    $whereStart 
    $whereEnd
''';

    final rows = await DB.execute(
      (txn) async {
        return await txn.rawQuery(q, params);
      },
    );

    final map = rows.firstOrNull ?? {};

    return _fromMap(model, map);
  }

  static LocationStatistics _fromMap(
      ModelGroup model, Map<String, Object?> map) {
    return LocationStatistics(
        model: model,
        count: TypeAdapter.deserializeInt(map[columnCount]),
        durationTotal: Duration(
            seconds: TypeAdapter.deserializeInt(map[columnDurationTotal])),
        durationMin: Duration(
            seconds: TypeAdapter.deserializeInt(map[columnDurationMin])),
        durationMax: Duration(
            seconds: TypeAdapter.deserializeInt(map[columnDurationMax])),
        durationAverage: Duration(
            seconds:
                TypeAdapter.deserializeInt(map[columnDurationAverage]).round()),
        tStart: TypeAdapter.dbIntToTime(map[columnFirstVisited]),
        tEnd: TypeAdapter.dbIntToTime(map[columnLastVisited]));
  }
}
