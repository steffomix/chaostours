import 'package:xml/xml.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/trackpoint.dart';
import 'package:chaostours/model/model_trackpoint.dart';
import 'package:chaostours/file_handler.dart';
import 'package:chaostours/address.dart';
import 'package:chaostours/shared/shared.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chaostours/logger.dart';

class SharedData {
  static final Logger logger = Logger.logger<SharedData>();

  /// prepare module
  static SharedPreferences? _shared;
  static Future<SharedPreferences> get shared async =>
      _shared ??= await SharedPreferences.getInstance();

  static const filename = 'shareddata.xml';

  static Future<void> test() async {
    var sd = SharedData();

    ModelTrackPoint mt = ModelTrackPoint(
        gps: GPS(100, 100),
        address: Address(GPS(-1, -1)),
        trackPoints: <GPS>[GPS(-1, -1), GPS(-2, -2)],
        idAlias: [1, 4, 8],
        timeStart: DateTime.now(),
        deleted: 0,
        notes: 'don\'t forget');
    sd.runningTrackPoints = [
      RunningTrackPoint(GPS(0, 0)),
      RunningTrackPoint(GPS(1, 1)),
      RunningTrackPoint(GPS(2, 2))
    ];
    sd.trackPoint = mt;
    sd.status = TrackingStatus.standing;
    sd.trackPoint = mt;
    sd.notes = 'pretty notes';
    sd.alias = <int>[1, 3, 6, 8];
    sd.tasks = <int>[4, 3, 2, 1];
    sd.address = 'over there near the old tree';

    //int bytes = await sd.write();

    sd = SharedData();
    await sd.read();
    var status = sd.status;
    var trackPoints = sd.runningTrackPoints;
    var trackPoint = sd.trackPoint;
    var notes = sd.notes;
    var tasks = sd.tasks;
    var alias = sd.alias;
    var address = sd.address;
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

  static String toNode(String node, String value) {
    return '<$node>$value</$node>';
  }

  String _status = toNode(nodeStatus, TrackingStatus.none.name);
  String _trackPoint = toNode(nodeTrackPoint, '');
  String _runningTrackPoints = toNode(nodeRunningTrackPoint, '');
  String _notes = toNode(nodeNotes, '');
  String _tasks = toNode(nodeTask, '');
  String _alias = toNode(nodeAlias, '');
  String _address = toNode(nodeAddress, '');

  XmlDocument? _xml;

  XmlDocument get xml {
    if (_xml == null) {
      throw ('xml not loaded. Use "await SharedData.read();" before using data');
    }
    return _xml!;
  }

  Future<XmlDocument> readShared() async {
    String f = (await shared).getString(filename) ??
        '<?xml version="1.0"?><data></data>';
    var doc = XmlDocument.parse(f);
    _xml = doc;
    return doc;
  }

  Future<XmlDocument> read() async {
    String f = await FileHandler.read(filename);
    XmlDocument doc = XmlDocument.parse(f);
    _xml = doc;
    return doc;
  }

  static Future<void> clearShared() async => await (await shared).clear();

  static Future<void> clear() async => FileHandler.write(filename, '');

  Future<bool> writeShared() async {
    bakeXml();
    return (await shared).setString(filename, xml.toXmlString(pretty: true));
    //return FileHandler.write(filename, xml.toXmlString(pretty: true));
  }

  Future<int> write() async {
    bakeXml();
    return await FileHandler.write(filename, xml.toXmlString(pretty: true));
  }

  /// get, set status
  TrackingStatus get status {
    String status = decode(textNode(nodeStatus));
    return status == ''
        ? TrackingStatus.none
        : TrackingStatus.values.byName(decode(textNode(nodeStatus)));
  }

  set status(TrackingStatus s) => _status = toNode(nodeStatus, encode(s.name));

  /// get, set trackpoint
  ModelTrackPoint? get trackPoint {
    try {
      ModelTrackPoint.toSharedModel(decode(textNode(nodeTrackPoint)));
    } catch (e, stk) {
      logger.warn('no trackpoint found in xml file');
    }
  }

  //
  set trackPoint(ModelTrackPoint? t) =>
      _trackPoint = toNode(nodeTrackPoint, encode(t!.toSharedString()));

  /// running status
  List<RunningTrackPoint> get runningTrackPoints {
    List<RunningTrackPoint> list = [];
    try {
      for (var child in node(nodeRunningTrackPoint).childElements.toList()) {
        list.add(RunningTrackPoint.toModel(decode(child.innerText)));
      }
    } catch (e, stk) {
      logger.warn('no running trackpoints found in xml file');
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
    try {
      for (var child in node(nodeTask).childElements) {
        taskList.add(int.parse(child.innerText));
      }
    } catch (e, stk) {
      logger.warn('no tasks found in xml file');
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
    try {
      for (var child in node(nodeAlias).childElements) {
        ids.add(int.parse(child.innerText));
      }
    } catch (e, stk) {
      logger.warn('no alias found in xml file');
    }
    return ids;
  }

  set address(String address) {
    _address = toNode(nodeAddress, encode(address));
  }

  String get address {
    return decode(textNode(nodeAddress));
  }

  void bakeXml() {
    _xml = XmlDocument.parse(<String>[
      xmlHead,
      '<root>',
      _status,
      _trackPoint,
      _runningTrackPoints,
      _notes,
      _tasks,
      _alias,
      _address,
      '</root>'
    ].join(lineSep));
  }

  XmlElement node(String name) {
    var el = xml.findAllElements(name);
    return el.first;
  }

  String textNode(String name) {
    var text = '';
    try {
      var el = xml.findAllElements(name);
      var first = el.first;
      text = first.text;
    } catch (e) {
      logger.warn('no elements found in $name');
    }
    return text;
  }
}
