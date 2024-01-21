// ignore_for_file: override_on_non_overriding_member

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
/* 
import 'package:chaostours/database/database.dart';
import 'package:chaostours/model/model.dart'; */

import 'package:chaostours/model/model_group.dart';

abstract class AssetStatistics {
  ModelGroup get model;
  int get count;
  Duration get durationTotal;
  Duration get durationMin;
  Duration get durationMax;
  Duration get durationAverage;
  DateTime get firstVisited;
  DateTime get lastVisited;

/*  
  static const _columnCount = 'ct';
  static const _columnDurationTotal = 'durationTotal';
  static const _columnDurationMin = 'durationMin';
  static const _columnDurationMax = 'durationMax';
  static const _columnDurationAverage = 'durationAverage';
  static const _columnFirstVisited = 'tStart';
  static const _columnLastVisited = 'tEnd'; 

  ModelAssetStatistics({
    this.count = 0,
    this.durationTotal,
    this.durationMin,
    this.durationMax,
    this.durationAverage,
    required DateTime tStart,
    required DateTime tEnd,
  }) {
    firstVisited = tStart;
    lastVisited = tEnd;
  }

  // Future<ModelAssetStatistics> reload({DateTime? start, DateTime? end});

  static ModelAssetStatistics fromMap(Map<String, Object?> map) {
    return ModelAssetStatistics(
        count: TypeAdapter.parseInt(map[_columnCount]),
        durationTotal:
            Duration(seconds: TypeAdapter.parseInt(map[_columnDurationTotal])),
        durationMin: Duration(seconds: TypeAdapter.parseInt(map[_columnDurationMin])),
        durationMax: Duration(seconds: TypeAdapter.parseInt(map[_columnDurationMax])),
        durationAverage:
            Duration(seconds: TypeAdapter.parseInt(map[_columnDurationAverage])),
        tStart: TypeAdapter.intToTime(map[_columnFirstVisited]),
        tEnd: TypeAdapter.intToTime(map[_columnLastVisited]));
  }

  /// ### example
  /// - tableAsset -- TableTrackPointAlias.table
  /// - columnTrackpointId -- TableTrackPointAlias.idTrackPoint
  /// - columnAssetId -- TableTrackPointAlias.idAlias
  static Future<ModelAssetStatistics> statistics(
      {required Model model,
      required String tableAsset,
      required String columnTrackpointId,
      required String columnAssetId}) async {
    final q = '''
    SELECT SUM(${TableTrackPoint.timeEnd.column} - ${TableTrackPoint.timeStart.column}) AS $_columnDurationTotal,
      MIN(${TableTrackPoint.timeEnd.column} - ${TableTrackPoint.timeStart.column}) AS $_columnDurationMin,
      MAX(${TableTrackPoint.timeEnd.column} - ${TableTrackPoint.timeStart.column}) AS $_columnDurationMax,
      ROUND(AVG(${TableTrackPoint.timeEnd.column} - ${TableTrackPoint.timeStart.column})) AS $_columnDurationAverage,
      MIN( ${TableTrackPoint.timeStart.column}) AS $_columnFirstVisited,
      MAX( ${TableTrackPoint.timeStart.column}) AS $_columnLastVisited,
      COUNT(*) AS $_columnCount
    FROM  $tableAsset -- ${TableTrackPointAlias.table}
    LEFT JOIN ${TableTrackPoint.table} ON ${TableTrackPoint.id} = $tableAsset.$columnTrackpointId -- ${TableTrackPointAlias.idTrackPoint}
    WHERE $tableAsset.$columnAssetId = ? -- ${TableTrackPointAlias.idAlias} 
''';

    final rows = await DB.execute(
      (txn) async {
        return await txn.rawQuery(q, [model.id]);
      },
    );

    return fromMap(rows.firstOrNull ?? {});
  } */
}
