import 'package:chaostours/model.dart';
import 'package:chaostours/log.dart';
import 'package:chaostours/file_handler.dart';
import 'package:chaostours/enum.dart';
import 'dart:io' as io;

class ModelTask {
  static List<ModelTask> _table = [];
  static int _nextId = 1;
  int _id = 1;

  final String task;
  final String notes;
  ModelTask({required this.task, this.notes = ''});

  static Future<int> insert(ModelTask m) async {
    _table.add(m);
    m._id = _table.length;
    await Model.writeLine(handle: await FileHandler.task, line: m.toString());
    return m._id;
  }

  static Future<int> open() async {
    List<String> lines = await FileHandler.readLines(FileHandle.task);
    _table.clear();
    Model.walkLines(lines, (row) => _table.add(toModel(row)));
    logInfo('tasks loaded ${_table.length} rows');
    return _table.length;
  }

  // writes the entire table back to disc
  static Future<bool> write() async {
    Model.writeTable(handle: await FileHandler.task, table: _table);
    return true;
  }

  @override
  String toString() {
    return '$_id\t${encode(task)}\t${encode(notes)}';
  }

  static ModelTask toModel(String row) {
    List<String> parts = row.split('\t');
    int id = int.parse(parts[0]);
    ModelTask model =
        ModelTask(task: decode(parts[1]), notes: decode(parts[2]));
    model._id = id;
    return model;
  }
}
