enum TrackingStatus {
  standing,
  moving,
  none;
}

enum AppBodyScreens {
  trackPointListView,
  trackPointEditView;
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
  tmpalias,
  task,
  tmptask,
  station,
  tmpstation;
}
