import 'package:flutter/widgets.dart';

class Screen {
  final BuildContext context;

  /// init with some secure values
  late double width;
  late double height;
  late EdgeInsets padding;
  late double newHeight;

  Screen(this.context) {
    width = MediaQuery.of(context).size.width;
    height = MediaQuery.of(context).size.height;
    // To get height just of SafeArea (for iOS 11 and above):
    padding = MediaQuery.of(context).padding;
    newHeight = height - padding.top - padding.bottom;
  }

  double percentWidth(double percent) {
    return width / 100 * percent;
  }

  double percentHeight(double percent) {
    return height / 100 * percent;
  }
}
