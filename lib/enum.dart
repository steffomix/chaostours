enum TrackingStatus {
  standing,
  moving;
}

enum AppBodyScreens {
  trackPointListView,
  trackPointEditView;
}

enum AliasStatus {
  disabled(0),
  public(2),
  privat(1);

  final int value;
  const AliasStatus(this.value);

  static AliasStatus byValue(int id) {
    AliasStatus status =
        AliasStatus.values.firstWhere((status) => status.value == id);
    return status;
  }
}

enum FileHandle {
  alias,
  alias_current,
  task,
  task_current,
  station,
  station_current;
}
