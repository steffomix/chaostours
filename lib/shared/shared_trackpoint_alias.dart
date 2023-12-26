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
import 'package:chaostours/model/model_alias.dart';
import 'package:chaostours/shared/shared_trackpoint_asset.dart';
import 'package:chaostours/database/cache.dart';

class SharedTrackpointAlias extends SharedTrackpointAsset {
  static final Logger logger = Logger.logger<SharedTrackpointAlias>();
  static const separator = r';';
  static final RegExp _regExp = RegExp([r'([0-9]+)', r'(.*)'].join(separator),
      dotAll: true, multiLine: true, caseSensitive: false);

  static SharedTrackpointAlias _toObject(String value) {
    String id = _regExp.firstMatch(value)?.group(1) ?? '';
    String notes = _regExp.firstMatch(value)?.group(2) ?? '';
    return SharedTrackpointAlias(id: int.parse(id), notes: notes);
  }

  static List<SharedTrackpointAlias> _toObjectList(List<String> list) {
    List<SharedTrackpointAlias> objects = [];
    for (var value in list) {
      try {
        objects.add(_toObject(value));
      } catch (e, stk) {
        logger.error('parse deatil: $e', stk);
      }
    }
    return objects;
  }

  static Future<void> add(ModelAlias model, {String notes = ''}) async {
    var tasks = await loadSharedList();
    for (var task in tasks) {
      if (task.id == model.id) {
        return;
      }
    }
    tasks.add(SharedTrackpointAlias(id: model.id, notes: notes));
    await save(tasks);
  }

  static Future<void> remove(int id) async {
    var tasks = await loadSharedList();
    tasks.removeWhere((task) => task.id == id);
    await save(tasks);
  }

  static Future<List<SharedTrackpointAlias>> loadSharedList() async {
    return _toObjectList(
        await Cache.backgroundSharedAliasList.load<List<String>>([]));
  }

  static Future<List<ModelAlias>> loadModelList() async {
    return await ModelAlias.byIdList(
        (await SharedTrackpointAlias.loadSharedList())
            .map(
              (shared) => shared.id,
            )
            .toList());
  }

  static Future<List<String>> save(List<SharedTrackpointAlias> tasks) async {
    return await Cache.backgroundSharedAliasList.save<List<String>>(tasks
        .map(
          (e) => e.toString(),
        )
        .toList());
  }

  SharedTrackpointAlias({required super.id, required super.notes});
}
