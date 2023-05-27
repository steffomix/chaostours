import 'dart:collection';

import 'package:chaostours/gps.dart';
import 'package:chaostours/model/model_alias.dart';

class Location {
  final GPS gps;

  final List<int> _aliasIdList = [];
  final List<ModelAlias> _aliasModelList = [];
  bool _isPublic = true;
  bool _isPrivate = false;
  bool _isResticted = false;

  List<int> get aliasIdList => UnmodifiableListView(_aliasIdList);
  List<ModelAlias> get aliasModelList => UnmodifiableListView(_aliasModelList);
  bool get isPublic => _isPublic;
  bool get isPrivate => _isPrivate;
  bool get isRestricted => _isResticted;
  bool get hasAlias => _aliasIdList.isNotEmpty;

  Location(this.gps) {
    List<ModelAlias> aliasList = [];
    for (var model in ModelAlias.nextAlias(gps: gps)) {
      if (!model.deleted) {
        aliasList.add(model);
      }
    }
    _aliasModelList.addAll(aliasList);
    _aliasIdList.addAll(aliasList.map((model) => model.id));
    for (var model in aliasList) {
      if (model.status == AliasStatus.restricted) {
        _isResticted = true;
        _isPrivate = true;
        _isPublic = false;
        return;
      }
      if (model.status == AliasStatus.privat) {
        _isResticted = false;
        _isPrivate = true;
        _isPublic = false;
        return;
      }
    }
    _isResticted = false;
    _isPrivate = false;
    _isPublic = true;
  }
}
