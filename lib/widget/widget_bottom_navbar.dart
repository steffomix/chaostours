import 'package:flutter/material.dart';
import 'package:chaostours/logger.dart';

class WidgetBottomNavBar extends StatefulWidget {
  const WidgetBottomNavBar({super.key});

  @override
  State<WidgetBottomNavBar> createState() => _WidgetBottomNavBar();
}

class _WidgetBottomNavBar extends State<WidgetBottomNavBar> {
  static final Logger logger = Logger.logger<WidgetBottomNavBar>();
  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.keyboard_arrow_left), label: 'x'),
          BottomNavigationBarItem(icon: Icon(Icons.location_city), label: 'x'),
          BottomNavigationBarItem(
              icon: Icon(Icons.keyboard_arrow_right), label: 'x'),
        ],
        onTap: (int id) {
          logger.log('BottomNavBar tapped but no method connected');
          //eventBusTapBottomNavBarIcon.fire(Tapped(id));
        });
  }
}
