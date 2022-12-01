class Logger {
  static const _logger = print;
  static const _infoLogger = print;
  static const _severeLogger = print;
  static bool _debugMode = true;

  static set debugMode(bool dbg) {
    _debugMode = dbg;
  }

  static log(String v) {
    if (_debugMode) _logger(v);
  }

  static info(String v) {
    if (_debugMode) _infoLogger(v);
  }

  static severe(String v) {
    if (_debugMode) _severeLogger(v);
  }
}

log(String msg) {
  Logger.log('LOG: $msg');
}

info(String msg) {
  // Logger.info('INFO: $msg');
}

severe(String msg) {
  Logger.severe('SEVERE: $msg');
}
