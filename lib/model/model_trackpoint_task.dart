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
import 'package:chaostours/model/model_trackpoint.dart';
import 'package:chaostours/model/model_trackpoint_asset.dart';

class ModelTrackpointTask extends ModelTrackpointAsset {
  ModelTrackpointTask(
      {required super.trackpointId, required super.id, required super.notes});

  static Future<List<ModelTrackpointTask>> select(
      ModelTrackPoint trackpoint) async {
    final rows = await DB.execute((txn) async {
      return await txn.query(TableTrackPointTask.table,
          columns: TableTrackPointTask.columns,
          where: '${TableTrackPointTask.idTrackPoint} = ?',
          whereArgs: [trackpoint.id]);
    });

    return rows
        .map(
          (e) => _fromMap(e),
        )
        .toList();
  }

  static ModelTrackpointTask _fromMap(Map<String, Object?> map) {
    return ModelTrackpointTask(
        trackpointId: DB.parseInt(map[TableTrackPointTask.idTrackPoint.column]),
        id: DB.parseInt(map[TableTrackPointTask.idTask.column]),
        notes: DB.parseString(map[TableTrackPointTask.notes.column]));
  }
}
