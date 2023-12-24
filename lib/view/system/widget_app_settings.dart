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

import 'package:flutter/material.dart';
import 'dart:math' as math;

///
//import 'package:chaostours/logger.dart';
import 'package:chaostours/channel/background_channel.dart';
import 'package:chaostours/view/app_widgets.dart';
import 'package:chaostours/conf/app_user_settings.dart';
import 'package:chaostours/database/cache.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

enum AliasRequired {
  yes(true),
  no(false);

  final bool state;

  const AliasRequired(this.state);
}

class WidgetAppSettings extends StatefulWidget {
  const WidgetAppSettings({super.key});

  @override
  State<WidgetAppSettings> createState() => _WidgetAppSettings();
}

typedef OnChangedBool = Function(
    {required AppUserSetting setting, required bool value});
typedef OnChangedInteger = Function(
    {required AppUserSetting setting, required int value});

class _WidgetAppSettings extends State<WidgetAppSettings> {
  //static final Logger logger = Logger.logger<WidgetAppSettings>();

  static const String infinity = '∞';

  static const divider = Divider();

  final Map<String, dynamic> _radioSettings = {};

  OsmLookupConditions _currentOsmCondition = OsmLookupConditions.never;
  final Map<Cache, ValueNotifier<int>> valueNotifiers = {};
  final Map<Cache, TextEditingController> textEditingControllers = {};
  final Map<Cache, UndoHistoryController> undoHistoryControllers = {};
  final List<Widget> _renderedWidgets = [];

  @override
  void dispose() {
    for (var value in valueNotifiers.values) {
      value.dispose();
    }
    super.dispose();
  }

  Future<bool> renderWidgets() async {
    await updateDebugValues();
    _renderedWidgets.clear();
    _renderedWidgets.addAll([
      await booleanSetting(Cache.appSettingBackgroundTrackingEnabled, onChange:
          ({required AppUserSetting setting, required bool value}) async {
        value
            ? await BackgroundChannel.start()
            : await BackgroundChannel.stop();
      }),
      divider,
      await booleanSetting(Cache.appSettingAutocreateAlias),
      divider,
      await booleanSetting(Cache.appSettingStatusStandingRequireAlias),
      divider,
      await booleanSetting(Cache.appSettingPublishToCalendar),
      divider,
      await integerSetting(Cache.appSettingForegroundUpdateInterval),
      divider,
      await integerSetting(Cache.appSettingDistanceTreshold),
      divider,
      await integerSetting(Cache.appSettingCacheGpsTime),
      divider,
      await settingOsmlookupCondition(),
      Container(
          decoration: BoxDecoration(border: Border.all()),
          margin: const EdgeInsets.all(10),
          child: Column(
            children: [
              const ListTile(
                  title: Text('Tracking calculating settings'),
                  subtitle: Text(
                      'These Settings depend on each other from top to bottom.\n'
                      'It is strongly recommended to modify the values in that order, because '
                      'the System will auto-adjust them if neccecary.')),
              divider,
              await integerSetting(Cache.appSettingBackgroundTrackingInterval,
                  onChange: (
                      {required AppUserSetting setting,
                      required int value}) async {
                //valueNotifiers[Cache.appSettingBackgroundTrackingInterval]?.value++;
                valueNotifiers[Cache.appSettingTimeRangeTreshold]?.value++;
                valueNotifiers[Cache.appSettingAutocreateAliasDuration]
                    ?.value++;
                valueNotifiers[Cache.appSettingGpsPointsSmoothCount]?.value++;
              }),
              await integerSetting(Cache.appSettingTimeRangeTreshold, onChange:
                  (
                      {required AppUserSetting setting,
                      required int value}) async {
                valueNotifiers[Cache.appSettingBackgroundTrackingInterval]
                    ?.value++;
                //valueNotifiers[Cache.appSettingTimeRangeTreshold]?.value++;
                valueNotifiers[Cache.appSettingAutocreateAliasDuration]
                    ?.value++;
                valueNotifiers[Cache.appSettingGpsPointsSmoothCount]?.value++;
              }),
              divider,
              await integerSetting(Cache.appSettingAutocreateAliasDuration,
                  onChange: (
                      {required AppUserSetting setting,
                      required int value}) async {
                valueNotifiers[Cache.appSettingBackgroundTrackingInterval]
                    ?.value++;
                valueNotifiers[Cache.appSettingTimeRangeTreshold]?.value++;
                // valueNotifiers[Cache.appSettingAutocreateAliasDuration]?.value++;
                valueNotifiers[Cache.appSettingGpsPointsSmoothCount]?.value++;
              }),
              divider,
              await integerSetting(Cache.appSettingGpsPointsSmoothCount),
            ],
          )),
      await radioSetting<DateFormat>(
          Cache.appSettingDateFormat, DateFormat.values),
      await radioSetting<Weekdays>(Cache.appSettingWeekdays, Weekdays.values),
      await radioSetting<GpsPrecision>(
          Cache.appSettingGpsPrecision, GpsPrecision.values),
    ]);
    return true;
  }

  final List<Widget> debugValues = [];
  Future<void> updateDebugValues() async {
    debugValues.clear();
    final smoothCount =
        await Cache.appSettingGpsPointsSmoothCount.load<int>(-1);
    final autoCreateDuration = await Cache.appSettingAutocreateAliasDuration
        .load<Duration>(Duration.zero);
    final trackingInterval = await Cache.appSettingBackgroundTrackingInterval
        .load<Duration>(Duration.zero);
    final distanceTreshold =
        await Cache.appSettingDistanceTreshold.load<int>(-1);
    final timeTreshold =
        await Cache.appSettingTimeRangeTreshold.load<Duration>(Duration.zero);

    valueNotifiers[Cache.appSettingGpsPointsSmoothCount]?.value++;
    valueNotifiers[Cache.appSettingAutocreateAliasDuration]?.value++;
    valueNotifiers[Cache.appSettingBackgroundTrackingInterval]?.value++;
    valueNotifiers[Cache.appSettingDistanceTreshold]?.value++;
    valueNotifiers[Cache.appSettingTimeRangeTreshold]?.value++;

    final gpsPoints =
        (autoCreateDuration.inSeconds / trackingInterval.inSeconds).ceil();

    final calcPoints = math.min(smoothCount - 1,
        (timeTreshold.inSeconds / trackingInterval.inSeconds).ceil());
    debugValues.addAll([
      Text('min autocreate Alias: '
          '${autoCreateDuration.inMinutes.toString()}'),
      Text('sec tracking Interval: '
          '${trackingInterval.inSeconds.toString()}'),
      Text('GPS Points: $gpsPoints'),
      divider,
      Text('min timeRange Treshold: '
          '${timeTreshold.inMinutes.toString()}'),
      Text('GPS calc points: $calcPoints'),
      Text('int smoothCount: ${smoothCount.toString()}'),
      divider,
      Text('m distanceTreshold: '
          '${distanceTreshold.toString()}'),
    ]);
  }

  Future<bool> checkIntegerInput(AppUserSetting setting, String? value) async {
    int unChecked =
        (int.tryParse(value ?? '') ?? -1) * setting.unit.multiplicator;
    int checked = await setting.pruneInt(value);
    return checked == unChecked;
  }

  Future<void> render() async {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: renderWidgets(),
      builder: (context, snapshot) {
        return AppWidgets.checkSnapshot(context, snapshot) ?? scaffold();
      },
    );
  }

  Widget scaffold() {
    return AppWidgets.scaffold(context, body: body());
  }

  Widget body() {
    return ListView(
      children: _renderedWidgets,
    );
  }

  Future<T> save<T>(Cache cache, T value) async {
    await cache.save<T>(value);
    valueNotifiers[cache]?.value++;
    return value;
  }

  void onSettingChanged(void Function() fn) {
    fn.call();
    FlutterBackgroundService()
        .invoke(BackgroundChannelCommand.reloadUserSettings.toString());
  }

  Future<Widget> booleanSetting(Cache cache, {OnChangedBool? onChange}) async {
    if (cache.cacheType != bool) {
      return AppWidgets.loading(Text('${cache.name} type is not bool'));
    }
    final setting = AppUserSetting(cache);

    Widget checkbox = AppWidgets.checkbox(
        value: await cache.load<bool>(false),
        onChanged: (value) async {
          onSettingChanged(() async {
            await save<bool>(cache, value ?? false);
            await onChange?.call(setting: setting, value: value ?? false);
          });
        });

    return ValueListenableBuilder(
      valueListenable: valueNotifiers[cache] ??= ValueNotifier<int>(0),
      builder: (context, _, __) {
        return ListTile(
          title: setting.title,
          subtitle: setting.description,
          leading: checkbox,
        );
      },
    );
  }

  Future<Widget> integerSetting(Cache cache,
      {OnChangedInteger? onChange}) async {
    AppUserSetting setting = AppUserSetting(cache);
    final controller =
        textEditingControllers[cache] ??= TextEditingController();
    controller.text = await setting.load();

    bool isValid = true;

    return ValueListenableBuilder(
        valueListenable: valueNotifiers[cache] ??= ValueNotifier<int>(0),
        builder: (context, _, __) {
          return Column(children: [
            ListTile(title: setting.title, subtitle: setting.description),
            ListTile(
                leading: IconButton(
                  icon: const Icon(Icons.settings_backup_restore),
                  onPressed: () async {
                    AppWidgets.dialog(context: context, contents: [
                      const Text('Reset to default?')
                    ], buttons: [
                      TextButton(
                        child: const Text('Cancel'),
                        onPressed: () => Navigator.pop(context),
                      ),
                      TextButton(
                        child: const Text('Yes'),
                        onPressed: () async {
                          onSettingChanged(() async {
                            await setting.resetToDefault();
                            textEditingControllers[cache]?.text =
                                await setting.load();
                            await updateDebugValues();
                            valueNotifiers[cache]?.value++;
                            if (mounted) {
                              Navigator.pop(context);
                            }
                          });
                        },
                      )
                    ]);
                  },
                ),
                title: TextField(
                  controller: controller,
                  undoController: undoHistoryControllers[cache] ??=
                      UndoHistoryController(),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp('[0-9]')),
                  ],
                  decoration: InputDecoration(
                      label: Text(
                          '${setting.minValue == null ? '0' : (setting.minValue! / setting.unit.multiplicator).round().toString()} - '
                          '${setting.maxValue == null ? infinity : (setting.maxValue! / setting.unit.multiplicator).round().toString()}'
                          ' ${setting.unit.name}',
                          style: isValid
                              ? null
                              : const TextStyle(color: Colors.red))),
                  onSubmitted: (_) async {
                    onSettingChanged(() async {
                      await setting.save(textEditingControllers[cache]!.text);
                      controller.text = await setting.load();
                      isValid = true;
                      await updateDebugValues();
                      valueNotifiers[cache]?.value++;

                      await onChange?.call(
                          setting: setting,
                          value: await setting
                              .pruneInt(textEditingControllers[cache]!.text));
                    });
                  },
                  onTapOutside: (_) async {
                    controller.text = await setting.load();
                    isValid = true;
                    valueNotifiers[cache]?.value++;
                  },
                  onChanged: (String? value) async {
                    isValid = await checkIntegerInput(setting, value);
                    valueNotifiers[cache]?.value++;
                  },
                ))
          ]);
        });
  }

  Future<Widget> radioSetting<T>(Cache cache, List<T> values) async {
    final setting = AppUserSetting(cache);
    _radioSettings[T.toString()] =
        await cache.load<T>(setting.defaultValue as T);
    return ValueListenableBuilder(
      valueListenable: valueNotifiers[cache] ??= ValueNotifier<int>(0),
      builder: (context, _, __) {
        return Column(
          children: [
            ListTile(
              title: setting.title,
              subtitle: setting.description,
            ),
            ...values.map(
              (T condition) {
                return Padding(
                    padding: const EdgeInsets.only(left: 20),
                    child: Row(children: [
                      Radio(
                        value: condition,
                        groupValue: _radioSettings[T.toString()],
                        onChanged: (value) async {
                          onSettingChanged(() async {
                            _radioSettings[T.toString()] =
                                await save<T>(cache, condition);
                          });
                        },
                      ),
                      (condition as EnumUserSetting).title
                    ]));
              },
            )
          ],
        );
      },
    );
  }

  Future<Widget> settingOsmlookupCondition() async {
    const cache = Cache.appSettingOsmLookupCondition;
    final setting = AppUserSetting(cache);
    _currentOsmCondition = await cache
        .load<OsmLookupConditions>(setting.defaultValue as OsmLookupConditions);
    return ValueListenableBuilder(
      valueListenable: valueNotifiers[cache] ??= ValueNotifier<int>(0),
      builder: (context, _, __) {
        return Column(
          children: [
            ListTile(
              title: setting.title,
              subtitle: setting.description,
            ),
            ...OsmLookupConditions.values.map(
              (condition) {
                return Padding(
                    padding: const EdgeInsets.only(left: 20),
                    child: Row(children: [
                      Checkbox(
                        value: _currentOsmCondition.index >= condition.index,
                        onChanged: (value) async {
                          onSettingChanged(() async {
                            _currentOsmCondition =
                                await save<OsmLookupConditions>(
                                    cache, condition);
                          });
                        },
                      ),
                      condition.title
                    ]));
              },
            )
          ],
        );
      },
    );
  }
}
