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
import 'package:chaostours/model/model_task.dart';
import 'package:chaostours/shared/shared_trackpoint_asset.dart';
import 'package:chaostours/database/cache.dart';

class SharedTrackpointTask extends SharedTrackpointAsset {
  static final Logger logger = Logger.logger<SharedTrackpointTask>();
  static const separator = r';';
  static final RegExp _regExp = RegExp([r'([0-9]+)', r'(.*)'].join(separator),
      dotAll: true, multiLine: true, caseSensitive: false);

  static SharedTrackpointTask toObject(String value) {
    String id = _regExp.firstMatch(value)?.group(1) ?? '';
    String desc = _regExp.firstMatch(value)?.group(2) ?? '';
    return SharedTrackpointTask(id: int.parse(id), notes: desc);
  }

  static Future<void> addTask(ModelTask model, {String notes = ''}) async {
    var tasks = await loadTasks();
    for (var task in tasks) {
      if (task.id == model.id) {
        return;
      }
    }
    tasks.add(SharedTrackpointTask(id: model.id, notes: notes));
    await saveTasks(tasks);
  }

  static Future<void> removeTask(int id) async {
    var tasks = await loadTasks();
    tasks.removeWhere((task) => task.id == id);
    await saveTasks(tasks);
  }

  static Future<List<SharedTrackpointTask>> loadTasks() async {
    return toObjectList(
        await Cache.backgroundSharedTaskList.load<List<String>>([]));
  }

  static Future<List<String>> saveTasks(
      List<SharedTrackpointTask> tasks) async {
    return await Cache.backgroundSharedTaskList.save<List<String>>(tasks
        .map(
          (e) => e.toString(),
        )
        .toList());
  }

  static List<SharedTrackpointTask> toObjectList(List<String> list) {
    List<SharedTrackpointTask> objects = [];
    for (var value in list) {
      try {
        objects.add(toObject(value));
      } catch (e, stk) {
        logger.error('parse deatil: $e', stk);
      }
    }
    return objects;
  }

  SharedTrackpointTask({required super.id, required super.notes});
}
