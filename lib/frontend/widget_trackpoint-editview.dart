import 'package:chaostours/events.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:chaostours/enum.dart';

class TrackPointEditView extends StatefulWidget {
  const TrackPointEditView({super.key});

  @override
  State<StatefulWidget> createState() => _TrackPointEditViewState();
}

class _TrackPointEditViewState extends State<TrackPointEditView> {
  StreamSubscription? _disposeListener;
  _TrackPointEditViewState() {
    _disposeListener ??=
        appBodyScreenChangedEvents.on<AppBodyScreens>().listen(_dispose);
  }

  void _dispose(AppBodyScreens id) {
    _disposeListener?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (PointerDownEvent e) {
        appBodyScreenChangedEvents.fire(AppBodyScreens.trackPointListView);
      },
      child: const Text('back'),
    );
  }
}
