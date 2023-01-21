import 'package:flutter/services.dart';
//
import 'package:chaostours/model/model.dart';
import 'package:chaostours/file_handler.dart';
import 'package:chaostours/enum.dart';
import 'package:chaostours/logger.dart';

class ModelTask {
  static Logger logger = Logger.logger<ModelTask>();
  static final List<ModelTask> _table = [];
  static int _unsavedId = 0;

  /// autoincrement unsaved models into negative ids
  static get _nextUnsavedId => --_unsavedId;
  int _id = 0;

  /// real ID<br>
  /// Is set only once during save to disk
  /// and represents the current _table.length
  int get id => _id;
  static int get length => _table.length;

  String task;
  String notes = '';
  int deleted;
  ModelTask({required this.task, this.notes = '', this.deleted = 0}) {
    _id = _nextUnsavedId;
  }

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
      encode(notes),
      '|'
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
    logger.log('Table Tasks loaded with ${_table.length} rows');
    return _table.length;
  }

  static Future<int> insert(ModelTask m) async {
    _table.add(m);
    m._id = _table.length;
    logger.log('Insert Task ${m.task} \n    which now has ID $m._id');
    await write();
    return m._id;
  }

  static Future<void> update() async {
    logger.verbose('Update');
    await write();
  }

  static Future<void> delete(ModelTask m) async {
    m.deleted = 1;
    logger.log('Delete Task ${m.task} with ID ${m.id}');
    await write();
  }

  // writes the entire table back to disc
  static Future<void> write() async {
    logger.verbose('Write Table');
    await Model.writeTable(handle: await FileHandler.task, table: _table);
  }

  static String dump() {
    List<String> dump = [];
    for (var i in _table) {
      dump.add(i.toString());
    }
    return dump.join('\n');
  }

  static Future<int> openFromAsset() async {
    logger.warn('Load built-in Tasks from assets');
    String string = await rootBundle.loadString('assets/task.tsv');
    List<String> lines = string.trim().split(Model.lineSep);
    _table.clear();
    for (var row in lines) {
      _table.add(toModel(row));
    }
    return _table.length;
  }
}