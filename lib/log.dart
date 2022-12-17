import 'package:logger/logger.dart';

var _logger = Logger(
  printer: PrettyPrinter(
      methodCount: 0, // number of method calls to be displayed
      errorMethodCount: 8, // number of method calls if stacktrace is provided
      lineLength: 120, // width of the output
      colors: true, // Colorful log messages
      printEmojis: true, // Print an emoji for each log message
      printTime: false // Should each log print contain a timestamp
      ),
);
var logVerbose = _logger.v;
var logInfo = _logger.i;
var logDebug = _logger.d;
var logWarn = _logger.w;
var logError = _logger.e;
var logFatal = _logger.wtf;

var log = _logger.d;
