class Logger {
  static const _logger = print;
  static bool _debugMode = true;

  static set debugMode(bool dbg) {
    _debugMode = dbg;
  }

  static log(String v) {
    if (_debugMode) _logger(v);
  }
}

log(String msg) {
  Logger.log(msg);
}
