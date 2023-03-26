import 'package:flutter/material.dart';
import 'package:chaostours/event_manager.dart';

class EventOnWidgetDisposed {}

class WidgetDisposed extends StatefulWidget {
  const WidgetDisposed({super.key});

  @override
  State<WidgetDisposed> createState() => _WidgetDisposed();
}

class _WidgetDisposed extends State<WidgetDisposed> {
  @override
  void dispose() {
    EventManager.fire<EventOnWidgetDisposed>(EventOnWidgetDisposed());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
