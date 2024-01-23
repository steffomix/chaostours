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
import 'package:chaostours/database/type_adapter.dart';
import 'package:chaostours/logger.dart';

class ModelTrackpointCalendar {
  static Logger logger = Logger.logger<ModelTrackpointCalendar>();

  final int idTrackPoint;
  final int idAliasGroup;
  String idCalendar = '';
  String idEvent = '';
  String title = '';
  String body = '';

  ModelTrackpointCalendar(
      {required this.idTrackPoint,
      required this.idAliasGroup,
      this.idCalendar = '',
      this.idEvent = '',
      this.title = '',
      this.body = ''});

  static ModelTrackpointCalendar fromMap(Map<String, Object?> map) {
    return ModelTrackpointCalendar(
      idTrackPoint: TypeAdapter.deserializeInt(
          map[TableTrackPointCalendar.idTrackPoint.column]),
      idAliasGroup: TypeAdapter.deserializeInt(
          map[TableTrackPointCalendar.idAliasGroup.column]),
      idCalendar: TypeAdapter.deserializeString(
          map[TableTrackPointCalendar.idCalendar.column]),
      idEvent: TypeAdapter.deserializeString(
          map[TableTrackPointCalendar.idEvent.column]),
      title: TypeAdapter.deserializeString(
          map[TableTrackPointCalendar.title.column]),
      body: TypeAdapter.deserializeString(
          map[TableTrackPointCalendar.body.column]),
    );
  }

  Map<String, Object?> toMap() {
    return {
      TableTrackPointCalendar.idTrackPoint.column: idTrackPoint,
      TableTrackPointCalendar.idAliasGroup.column: idAliasGroup,
      TableTrackPointCalendar.idCalendar.column: idCalendar,
      TableTrackPointCalendar.idEvent.column: idEvent,
      TableTrackPointCalendar.title.column: title,
      TableTrackPointCalendar.body.column: body,
    };
  }

  Future<ModelTrackpointCalendar> insertOrUpdate() async {
    var update = false;
    final where =
        '${TableTrackPointCalendar.idTrackPoint} = ? AND ${TableTrackPointCalendar.idAliasGroup} = ?';
    final whereArgs = [idTrackPoint, idAliasGroup];

    const rowCount = 'ct';
    var rows = await DB.execute((txn) async {
      return await txn.query(TableTrackPointCalendar.table,
          columns: [TableTrackPointCalendar.idTrackPoint.column],
          where: where,
          whereArgs: whereArgs);
    });
    await Future.delayed(const Duration(milliseconds: 200));
    update = TypeAdapter.deserializeInt(rows.firstOrNull?[rowCount]) > 0;
    await DB.execute((txn) async {
      if (update) {
        await txn.update(TableTrackPointCalendar.table, toMap(),
            where: where, whereArgs: whereArgs);
      } else {
        await txn.insert(TableTrackPointCalendar.table, toMap());
      }
    });
    return this;
  }
}
