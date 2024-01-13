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

import 'package:chaostours/database/cache.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/model/model_user.dart';
import 'package:chaostours/shared/shared_trackpoint_asset.dart';

class SharedTrackpointUser extends SharedTrackpointAsset {
  static final Logger logger = Logger.logger<SharedTrackpointUser>();
  static const separator = r';';
  static final RegExp _regExp = RegExp([r'([0-9]+)', r'(.*)'].join(separator),
      dotAll: true, multiLine: true, caseSensitive: false);

  static SharedTrackpointUser toObject(String value) {
    String id = _regExp.firstMatch(value)?.group(1) ?? '';
    String desc = _regExp.firstMatch(value)?.group(2) ?? '';
    return SharedTrackpointUser(id: int.parse(id), notes: desc);
  }

  static Future<List<SharedTrackpointUser>> addOrUpdate(ModelUser model,
      {String notes = ''}) async {
    var models = await load();
    for (var m in models) {
      if (m.id == model.id) {
        m.notes = notes;
        await save(models);
        return models;
      }
    }
    models.add(SharedTrackpointUser(id: model.id, notes: notes));
    return await save(models);
  }

  static Future<List<SharedTrackpointUser>> remove(ModelUser model) async {
    var models = await load();
    models.removeWhere((m) => m.id == model.id);
    return await save(models);
  }

  static Future<List<SharedTrackpointUser>> load() async {
    return await Cache.backgroundSharedUserList
        .load<List<SharedTrackpointUser>>([]);
  }

  static Future<List<SharedTrackpointUser>> save(
      List<SharedTrackpointUser> models) async {
    return await Cache.backgroundSharedUserList
        .save<List<SharedTrackpointUser>>(models);
  }

  SharedTrackpointUser({required super.id, required super.notes});
}
