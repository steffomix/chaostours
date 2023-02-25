import 'package:flutter/services.dart';
//
import 'package:chaostours/file_handler.dart';
import 'package:chaostours/logger.dart';

class ModelTask {
  static Logger logger = Logger.logger<ModelTask>();
  static final List<ModelTask> _table = [];
  int _id = 0;

  /// real ID<br>
  /// Is set only once during save to disk
  /// and represents the current _table.length
  int get id => _id;
  static int get length => _table.length;

  String task;
  String notes = '';
  bool deleted;
  ModelTask({required this.task, this.notes = '', this.deleted = false});

  static ModelTask getTask(int id) {
    return _table[id - 1];
  }

  static List<ModelTask> getAll() => <ModelTask>[..._table];

  @override
  String toString() {
    List<String> parts = [
      _id.toString(),
      deleted ? '1' : '0',
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
        deleted: parts[1] == '1' ? true : false,
        task: decode(parts[2]),
        notes: decode(parts[3]));
    model._id = id;
    return model;
  }

  static Future<int> open() async {
    List<String> lines = await FileHandler.readTable<ModelTask>();
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

  static Future<void> update([ModelTask? m]) async {
    if (m != null && _table.indexWhere((e) => e.id == m.id) >= 0) {
      _table[m.id - 1] = m;
    }
    await write();
  }

  ModelTask clone() {
    return toModel(toString());
  }

  static Future<void> delete(ModelTask m) async {
    m.deleted = true;
    logger.log('Delete Task ${m.task} with ID ${m.id}');
    await write();
  }

  // writes the entire table back to disc
  static Future<void> write() async {
    logger.verbose('Write Table');
    await FileHandler.writeTable<ModelTask>(
        _table.map((e) => e.toString()).toList());
  }

  static String dump() {
    List<String> dump = [];
    for (var i in _table) {
      dump.add(i.toString());
    }
    return dump.join(FileHandler.lineSep);
  }

  static Future<int> openFromAsset() async {
    logger.warn('Load built-in Tasks from assets');
    String string = await rootBundle.loadString('assets/task.tsv');
    List<String> lines = string.trim().split(FileHandler.lineSep);
    _table.clear();
    for (var row in lines) {
      _table.add(toModel(row));
    }
    return _table.length;
  }
}
