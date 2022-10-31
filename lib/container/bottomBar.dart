import 'package:flutter/material.dart';

const item1 = BottomNavigationBarItem(icon: Icon(Icons.home), label: 'home');
const item2 =
    BottomNavigationBarItem(icon: Icon(Icons.add_link), label: 'Aktionen');
const item3 = BottomNavigationBarItem(icon: Icon(Icons.timer), label: 'Timer');

class BottomBar extends StatefulWidget {
  const BottomBar({super.key});

  @override
  State<BottomBar> createState() => _BottomBarState();
}

class _BottomBarState extends State<BottomBar> {
  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
        items: const <BottomNavigationBarItem>[item1, item2, item3]);
  }
}
