import 'package:flutter/material.dart';
import 'package:chaostours/logger.dart';

class Widgets {
  static final Logger logger = Logger.logger<Widgets>();
  static AppBar appBar() {
    return AppBar(title: const Text('ChaosTours'));
  }
}
