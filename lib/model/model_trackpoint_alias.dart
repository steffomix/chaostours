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

class ModelTrackpointAlias extends ModelTrackpointAsset {
  ModelTrackpointAlias(
      {required super.trackpointId, required super.id, required super.notes});

  static Future<List<ModelTrackpointAlias>> select(
      ModelTrackPoint trackpoint) async {
    final rows = await DB.execute((txn) async {
      return await txn.query(TableTrackPointAlias.table,
          columns: TableTrackPointAlias.columns,
          where: '${TableTrackPointAlias.idTrackPoint} = ?',
          whereArgs: [trackpoint.id]);
    });

    return rows
        .map(
          (e) => _fromMap(e),
        )
        .toList();
  }

  static ModelTrackpointAlias _fromMap(Map<String, Object?> map) {
    return ModelTrackpointAlias(
        trackpointId:
            DB.parseInt(map[TableTrackPointAlias.idTrackPoint.column]),
        id: DB.parseInt(map[TableTrackPointAlias.idAlias.column]),
        notes: DB.parseString(map[TableTrackPointAlias.notes.column]));
  }
}
