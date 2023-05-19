var decode = Uri.decodeFull; // util.base64Codec().decode;
var encode = Uri.encodeFull;

class Model {
  static const String lineSep = '\n';
  String _data = '';

  Model.raw({String? row}) {
    row ??= '';
    if (row.contains(lineSep)) {
      throw (r'Model.raw:: string must not contain a lineseparator ' + lineSep);
    }
    _data = row;
  }

  @override
  toString() {
    return _data;
  }
}
