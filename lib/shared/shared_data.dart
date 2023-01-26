import 'package:xml/xml.dart';
import 'package:chaostours/trackpoint.dart';
import 'package:chaostours/model/model_trackpoint.dart';

class SharedData {
  static const String lineSep = '\n';
  static const String xmlHead = '<?xml version="1.0"?>';

  /// encode, decode
  static String encode(String s) => Uri.encodeFull(s);
  static String decode(String s) => Uri.decodeFull(s);

  /// xml nodes
  final String nodeStatus = 'status';
  final String nodeTrackPoint = 'trackpoint';
  final String nodeRunningTrackPoints = 'runningtrackpoints';
  final String nodeNotes = 'notes';
  final String nodeTask = 'task';
  final String nodeParentTasks = 'tasks';
  final String nodeAlias = 'alias';
  final String nodeAddress = 'address';
  final String nodeListElement = 'node';

  String _status = 'none';
  String _trackPoint = '';
  String _runningTrackPoints = '';
  String _notes = '';
  String _tasks = '';
  String _alias = '';
  String _address = '';

  XmlDocument _xml = XmlDocument.parse('');

  /// get, set status
  TrackingStatus get status {
    return TrackingStatus.values.byName(decode(textNode(nodeStatus)));
  }

  set status(TrackingStatus s) => _status = toNode(nodeStatus, encode(s.name));

  /// get, set trackpoint
  ModelTrackPoint get trackPoint =>
      ModelTrackPoint.toSharedModel(decode(textNode(nodeTrackPoint)));
  //
  set trackPoint(ModelTrackPoint t) =>
      _trackPoint = toNode(nodeTrackPoint, encode(t.toSharedString()));

  /// running status
  List<RunningTrackPoint> get runningTrackPoints {
    List<RunningTrackPoint> list = [];
    var children = node(nodeRunningTrackPoints).children;
    for (var child in children) {
      list.add(RunningTrackPoint.toModel(decode(child.innerText)));
    }
    return list;
  }

  set runningTrackPoints(List<RunningTrackPoint> tpList) {
    List<String> xmlList = [];
    for (var tp in tpList) {
      xmlList.add(toNode(nodeListElement, encode(tp.toSharedString())));
    }
    _runningTrackPoints = toNode(nodeRunningTrackPoints, xmlList.join(lineSep));
  }

  set notes(String n) {
    _notes = toNode(nodeNotes, encode(n));
  }

  String get notes {
    return decode(textNode(nodeNotes));
  }

  /// tasks id list
  set tasks(List<int> t) {
    List<String> taskList = [];
    for (var task in t) {
      taskList.add(toNode(nodeListElement, task.toString()));
    }
    _tasks = toNode(nodeTask, taskList.join(lineSep));
  }

  List<int> get tasks {
    List<int> taskList = [];
    for (var child in node(nodeTask).children) {
      taskList.add(int.parse(child.innerText));
    }
    return taskList;
  }

  /// alias id list
  set alias(List<int> alias) {
    List<String> aliasList = [];
    for (var a in alias) {
      aliasList.add(toNode(nodeAlias, a.toString()));
    }
    _alias = toNode(nodeAlias, aliasList.join(lineSep));
  }

  List<int> get alias {
    List<int> ids = [];
    for (var child in node(nodeAlias).children) {
      ids.add(int.parse(child.innerText));
    }
    return ids;
  }

  set address(String address) {
    _address = toNode(nodeAddress, encode(address));
  }

  String get address {
    return decode(textNode(nodeAddress));
  }

  XmlDocument get xmlDocument {
    String sx = <String>[
      xmlHead,
      _status,
      _trackPoint,
      _runningTrackPoints,
      _notes,
      _tasks,
      _alias,
      _address
    ].join(lineSep);

    return XmlDocument.parse(sx);
  }

  XmlElement node(String name) {
    return _xml.findAllElements(name).first;
  }

  String textNode(String name) {
    return _xml.findAllElements(name).first.innerText;
  }

  String toNode(String node, String value) {
    return '<$node>$value</$node>';
  }
}
