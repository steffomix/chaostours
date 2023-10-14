import 'package:chaostours/conf/app_settings.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/app_logger.dart';
import 'package:chaostours/model/model_alias.dart';

class Location {
  static final AppLogger logger = AppLogger.logger<Location>();
  final GPS gps;

  final List<ModelAlias> aliasModels;
  List<int> get aliasIds => aliasModels.map((e) => e.id).toList();
  final bool isPublic;
  final bool isPrivate;
  final bool isRestricted;
  final AliasVisibility visibility;
  bool get hasAlias => aliasModels.isNotEmpty;

  Location(
      {required this.gps,
      required this.visibility,
      required this.aliasModels,
      required this.isPublic,
      required this.isPrivate,
      required this.isRestricted});

  static Future<Location> location(GPS gps) async {
    /// location defaults
    List<ModelAlias> models = [];
    AliasVisibility visibility = AliasVisibility.public;
    bool isRestricted = false;
    bool isPrivate = false;
    bool isPublic = true;
    try {
      models.addAll(await ModelAlias.nextAlias(
          gps: gps, area: AppSettings.distanceTreshold));

      for (var model in models) {
        if (model.visibility == AliasVisibility.restricted) {
          visibility = AliasVisibility.restricted;
          isRestricted = true;
          isPrivate = true;
          isPublic = false;
        }
        if (model.visibility == AliasVisibility.privat) {
          visibility = AliasVisibility.privat;
          isRestricted = false;
          isPrivate = true;
          isPublic = false;
        }
      }
    } catch (e, stk) {
      logger.error('create location: $e', stk);
    }
    return Location(
        aliasModels: models,
        gps: gps,
        visibility: visibility,
        isPrivate: isPrivate,
        isPublic: isPublic,
        isRestricted: isRestricted);
  }
}
