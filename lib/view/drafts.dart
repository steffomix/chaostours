import 'package:flutter/material.dart';

class WidgetListViewQuestion extends StatefulWidget {
  const WidgetListViewQuestion({super.key});

  @override
  State<WidgetListViewQuestion> createState() => _WidgetListViewQuestion();
}

class _WidgetListViewQuestion extends State<WidgetListViewQuestion> {
  List<Widget> items = [];
  void createItem() => Future.delayed(const Duration(seconds: 2), () {
        items.insert(0, Text('Item #${items.length}'));
        setState(() {});
      });

  @override
  void initState() {
    createItem();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(children: [...items]);
  }
}
