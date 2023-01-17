import 'package:flutter/material.dart';
//
import 'package:chaostours/widget/widget_trackpoints_listview.dart';
import 'package:chaostours/widget/widget_settings_permissions.dart';
import 'package:chaostours/widget/widget_logger.dart';

enum TrackingStatus {
  none(0),
  standing(1),
  moving(2);

  final int value;
  const TrackingStatus(this.value);

  static TrackingStatus byValue(int id) {
    TrackingStatus status =
        TrackingStatus.values.firstWhere((status) => status.value == id);
    return status;
  }
}

// pane widgets that does't need any initial values
enum Panes {
  trackPointList,
  permissions,
  logger;

  static Widget instance(Panes pane) {
    switch (pane) {
      case Panes.logger:
        return const WidgetLogger();

      case Panes.permissions:
        return const WidgetSettingsPermissions();

      default:
        return const WidgetTrackPointList();
    }
  }
}

enum AliasStatus {
  disabled(0),
  public(1),
  privat(2);

  final int value;
  const AliasStatus(this.value);

  static AliasStatus byValue(int id) {
    AliasStatus status =
        AliasStatus.values.firstWhere((status) => status.value == id);
    return status;
  }
}

enum DatabaseFile {
  alias,
  task,
  station;
}
