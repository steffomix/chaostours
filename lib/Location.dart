/*
Copyright 2023 Stefan Brinkmann <st.brinkmann@gmail.com>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

import 'package:chaostours/cache.dart';
import 'package:chaostours/conf/app_user_settings.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/model/model_alias.dart';

class Location {
  static final Logger logger = Logger.logger<Location>();
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
      models.addAll(await ModelAlias.byArea(
          gps: gps,
          area: await Cache.appSettingDistanceTreshold.load(
              AppUserSetting(Cache.appSettingDistanceTreshold).defaultValue
                  as int)));

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
