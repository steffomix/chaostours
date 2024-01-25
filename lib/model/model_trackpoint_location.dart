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
import 'package:chaostours/gps.dart';
import 'package:chaostours/model/model_trackpoint_asset.dart';
import 'package:chaostours/model/model_location.dart';

class ModelTrackpointLocation implements ModelTrackpointAsset {
  @override
  final ModelLocation model;

  @override
  final int trackpointId;
  @override
  final String notes;

  @override
  int get id => model.id;
  @override
  String get sortOrder => '';
  @override
  String get title => model.title;
  @override
  String get description => model.description;

  @override
  Future<int> updateNotes(String notes) async {
    return await DB.execute((txn) async {
      return await txn.update(TableTrackPointLocation.table,
          {TableTrackPointLocation.notes.column: notes},
          where:
              '${TableTrackPointLocation.idTrackPoint} = ? AND ${TableTrackPointLocation.idLocation} = ?',
          whereArgs: [trackpointId, id]);
    });
  }

  ModelTrackpointLocation(
      {required this.model, required this.trackpointId, required this.notes});

  /// location only
  int distance(GPS gps) => GPS.distance(gps, model.gps).round();
}
