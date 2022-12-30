import 'package:chaostours/model.dart';
import 'package:chaostours/log.dart';
import 'package:chaostours/file_handler.dart';
import 'package:chaostours/enum.dart';

class ModelTask {
  static final List<ModelTask> _table = [];
  int _id = 1;
  int get id => _id;
  static int get length => _table.length;

  final int deleted;
  final String task;
  final String notes;
  ModelTask({required this.task, this.notes = '', this.deleted = 0});

  static ModelTask getTask(int id) {
    return _table[id - 1];
  }

  static Future<int> insert(ModelTask m) async {
    _table.add(m);
    m._id = _table.length;
    await Model.insertRow(handle: await FileHandler.task, line: m.toString());
    return m._id;
  }

  static Future<int> open() async {
    List<String> lines = await FileHandler.readLines(DatabaseFile.task);
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
}
