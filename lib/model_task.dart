import 'package:chaostours/model.dart';
import 'package:chaostours/log.dart';
import 'package:chaostours/file_handler.dart';
import 'package:chaostours/enum.dart';
import 'package:flutter/services.dart';

class ModelTask {
  static final List<ModelTask> _table = [];
  int _id = 1;
  int get id => _id;
  static int get length => _table.length;

  String task;
  String notes = '';
  int deleted;
  ModelTask({required this.task, this.notes = '', this.deleted = 0});

  static ModelTask getTask(int id) {
    return _table[id - 1];
  }

  static List<ModelTask> getAll() => <ModelTask>[..._table];

  @override
  String toString() {
    List<String> parts = [
      _id.toString(),
      deleted.toString(),
      encode(task),
      encode(notes)
    ];
    return parts.join('\t');
  }

  static ModelTask toModel(String row) {
    List<String> parts = row.split('\t');
    int id = int.parse(parts[0]);
    ModelTask model = ModelTask(
        deleted: int.parse(parts[1]),
        task: decode(parts[2]),
        notes: decode(parts[3]));
    model._id = id;
    return model;
  }

  static Future<int> open() async {
    List<String> lines = await Model.readTable(DatabaseFile.task);
    _table.clear();
    for (var row in lines) {
      _table.add(toModel(row));
    }
    logInfo('tasks loaded ${_table.length} rows');
    return Future<int>.value(_table.length);
  }

  static Future<int> insert(ModelTask m) async {
    _table.add(m);
    m._id = _table.length;
    await write();
    return Future<int>.value(m._id);
  }

  static Future<bool> update() async {
    await write();
    return Future<bool>.value(true);
  }

  static Future<bool> delete(ModelTask m) async {
    m.deleted = 1;
    await write();
    return Future<bool>.value(true);
  }

  // writes the entire table back to disc
  static Future<bool> write() async {
    Model.writeTable(handle: await FileHandler.task, table: _table);
    return Future<bool>.value(true);
  }

  static Future<int> openFromAsset() async {
    String string = await rootBundle.loadString('assets/task.tsv');
    List<String> lines = string.trim().split(Model.lineSep);
    _table.clear();
    for (var row in lines) {
      _table.add(toModel(row));
    }
    return _table.length;
  }
}
