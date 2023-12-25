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

import 'package:chaostours/logger.dart';
import 'package:chaostours/model/model_user.dart';
import 'package:chaostours/shared/shared_trackpoint_asset.dart';
import 'package:chaostours/database/cache.dart';

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

  static Future<void> addUser(ModelUser model, {String notes = ''}) async {
    var tasks = await loadUsers();
    for (var task in tasks) {
      if (task.id == model.id) {
        return;
      }
    }
    tasks.add(SharedTrackpointUser(id: model.id, notes: notes));
    await saveUsers(tasks);
  }

  static Future<void> removeUser(int id) async {
    var tasks = await loadUsers();
    tasks.removeWhere((task) => task.id == id);
    await saveUsers(tasks);
  }

  static Future<List<SharedTrackpointUser>> loadUsers() async {
    return toObjectList(
        await Cache.backgroundSharedUserList.load<List<String>>([]));
  }

  static Future<List<String>> saveUsers(
      List<SharedTrackpointUser> tasks) async {
    return await Cache.backgroundSharedUserList.save<List<String>>(tasks
        .map(
          (e) => e.toString(),
        )
        .toList());
  }

  static List<SharedTrackpointUser> toObjectList(List<String> list) {
    List<SharedTrackpointUser> objects = [];
    for (var value in list) {
      try {
        objects.add(toObject(value));
      } catch (e, stk) {
        logger.error('parse deatil: $e', stk);
      }
    }
    return objects;
  }

  SharedTrackpointUser({required super.id, required super.notes});
}
