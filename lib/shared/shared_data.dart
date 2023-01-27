import 'package:xml/xml.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/trackpoint.dart';
import 'package:chaostours/model/model_trackpoint.dart';
import 'package:chaostours/file_handler.dart';
import 'package:chaostours/address.dart';

class SharedData {
  static const filename = 'shareddata.xml';
  static Future<void> test() async {
    var sd = SharedData();
    sd.runningTrackPoints = [
      RunningTrackPoint(GPS(0, 0)),
      RunningTrackPoint(GPS(1, 1)),
      RunningTrackPoint(GPS(2, 2))
    ];
    ModelTrackPoint mt = ModelTrackPoint(
        gps: GPS(100, 100),
        address: Address(GPS(-1, -1)),
        trackPoints: <GPS>[GPS(-1, -1), GPS(-2, -2)],
        idAlias: [1, 4, 8],
        timeStart: DateTime.now(),
        deleted: 0,
        notes: 'don\'t forget');
    //sd. trackPoints = <ModelTrackPoint>[mt, mt, mt, mt];
    sd.status = TrackingStatus.standing;
    sd.trackPoint = mt;
    sd.notes = 'pretty notes';
    sd.alias = <int>[1, 3, 6, 8];
    sd.tasks = <int>[4, 3, 2, 1];
    sd.address = 'over there near the old tree';

    String xml = sd.xml.toXmlString(pretty: true);

    //var status = sd.status;
    var trackPoints = sd.runningTrackPoints;
    var trackPoint = sd.trackPoint;
    var notes = sd.notes;
    var tasks = sd.tasks;
    var alias = sd.alias;
    var address = sd.address;
    String x = await sd.write();
    sd.read();
  }

  static const String lineSep = '\n';
  static const String xmlHead = '<?xml version="1.0"?>';

  /// encode, decode
  static String encode(String s) => Uri.encodeFull(s);
  static String decode(String s) => Uri.decodeFull(s);

  /// xml nodes
  static const String nodeStatus = 'status';
  static const String nodeTrackPoint = 'trackpoint';
  static const String nodeRunningTrackPoint = 'runningtrackpoints';
  static const String nodeNotes = 'notes';
  static const String nodeTask = 'task';
  static const String nodeAlias = 'alias';
  static const String nodeAddress = 'address';
  static const String nodeListElement = 'node';

  String _status = '';
  String _trackPoint = '';
  String _runningTrackPoints = '';
  String _notes = '';
  String _tasks = '';
  String _alias = '';
  String _address = '';

  XmlDocument _xml = XmlDocument.parse('$xmlHead\n<root></root>');

  read() async => await FileHandler.read(filename);
  write() async =>
      await FileHandler.write(filename, xml.toXmlString(pretty: true));

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
    for (var child in node(nodeRunningTrackPoint).childElements) {
      list.add(RunningTrackPoint.toModel(decode(child.innerText)));
    }
    return list;
  }

  set runningTrackPoints(List<RunningTrackPoint> tpList) {
    List<String> xmlList = [];
    for (var tp in tpList) {
      xmlList.add(toNode(nodeListElement, encode(tp.toSharedString())));
    }
    _runningTrackPoints = toNode(nodeRunningTrackPoint, xmlList.join(lineSep));
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
    for (var child in node(nodeTask).childElements) {
      taskList.add(int.parse(child.innerText));
    }
    return taskList;
  }

  /// alias id list
  set alias(List<int> alias) {
    List<String> aliasList = [];
    for (var a in alias) {
      aliasList.add(toNode(nodeListElement, a.toString()));
    }
    _alias = toNode(nodeAlias, aliasList.join(lineSep));
  }

  List<int> get alias {
    List<int> ids = [];
    for (var child in node(nodeAlias).childElements) {
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

  XmlDocument get xml {
    String root = 'chaostours_shared_data';
    String sx = <String>[
      xmlHead,
      '<$root>',
      _status,
      _trackPoint,
      _runningTrackPoints,
      _notes,
      _tasks,
      _alias,
      _address,
      '</$root>'
    ].join(lineSep);

    return XmlDocument.parse(sx);
  }

  set xml(XmlDocument doc) {
    _xml = doc;
  }

  XmlElement node(String name) {
    var el = xml.findAllElements(name);
    return el.first;
  }

  String textNode(String name) {
    var el = xml.findAllElements(name);
    var first = el.first;
    var text = first.innerText;
    return text;
    //return _xml.findAllElements(name).first.innerText;
  }

  String toNode(String node, String value) {
    return '<$node>$value</$node>';
  }
}
