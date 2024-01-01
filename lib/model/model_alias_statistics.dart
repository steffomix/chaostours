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

import 'package:chaostours/database/database.dart';
import 'package:chaostours/model/model_alias.dart';

class ModelAliasStatistics {
  static const columnCount = 'ct';
  static const columnDurationTotal = 'durationTotal';
  static const columnDurationMin = 'durationMin';
  static const columnDurationMax = 'durationMax';
  static const columnFirstVisited = 'tStart';
  static const columnLastVisited = 'tEnd';

  int count = 0;
  Duration durationTotal = Duration.zero;
  Duration durationMin = Duration.zero;
  Duration durationMax = Duration.zero;
  late DateTime timeStart;
  late DateTime timeEnd;

  ModelAliasStatistics({
    this.count = 0,
    this.durationTotal = Duration.zero,
    this.durationMin = Duration.zero,
    this.durationMax = Duration.zero,
    required DateTime tStart,
    required DateTime tEnd,
  }) {
    timeStart = tStart;
    timeEnd = tEnd;
  }

  static ModelAliasStatistics fromMap(Map<String, Object?> map) {
    return ModelAliasStatistics(
        count: DB.parseInt(map[columnCount]),
        durationTotal: Duration(seconds: DB.parseInt(map[columnDurationTotal])),
        durationMin: Duration(seconds: DB.parseInt(map[columnDurationMin])),
        durationMax: Duration(seconds: DB.parseInt(map[columnDurationMax])),
        tStart: DB.intToTime(map[columnFirstVisited]),
        tEnd: DB.intToTime(map[columnLastVisited]));
  }

  static Future<ModelAliasStatistics> statistics(ModelAlias model) async {
    final q = '''
    SELECT SUM(${TableTrackPoint.timeEnd.column} - ${TableTrackPoint.timeStart.column}) AS $columnDurationTotal,
      MIN(${TableTrackPoint.timeEnd.column} - ${TableTrackPoint.timeStart.column}) AS $columnDurationMin,
      MAX(${TableTrackPoint.timeEnd.column} - ${TableTrackPoint.timeStart.column}) AS $columnDurationMax,
      MIN( ${TableTrackPoint.timeStart.column}) AS $columnFirstVisited,
      MAX( ${TableTrackPoint.timeStart.column}) AS $columnLastVisited,
      COUNT(*) AS $columnCount
    FROM ${TableTrackPointAlias.table}
    LEFT JOIN ${TableTrackPoint.table} ON ${TableTrackPoint.id} = ${TableTrackPointAlias.idTrackPoint}
    WHERE ${TableTrackPointAlias.idAlias} = ?
''';

    final rows = await DB.execute(
      (txn) async {
        return await txn.rawQuery(q, [model.id]);
      },
    );

    return fromMap(rows.firstOrNull ?? {});
  }
}
