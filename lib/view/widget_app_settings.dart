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
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';

import 'package:chaostours/globals.dart';
import 'package:chaostours/data_bridge.dart';
import 'package:chaostours/view/app_widgets.dart';
import 'package:chaostours/cache.dart';
import 'package:chaostours/logger.dart';

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

class _WidgetAppSettings extends State<WidgetAppSettings> {
  static final Logger logger = Logger.logger<WidgetAppSettings>();

  bool? statusStandingRequireAlias = Globals.statusStandingRequireAlias;
  bool? backgroundTrackingEnabled = Globals.backgroundTrackingEnabled;

  TextEditingController? txTrackPointInterval;
  TextEditingController? txAddressLookupInterval;
  TextEditingController? txCacheGpsTime;
  TextEditingController? txDistanceTrehold;
  TextEditingController? txTimeRangeTreshold;
  TextEditingController? txAppTickDuration;
  TextEditingController? txGpsSmoothCount;
  TextEditingController? txGpsMaxSpeed;

  static Map<CacheKeys, String> settings = {
    CacheKeys.globalsBackgroundTrackingEnabled:
        Globals.backgroundTrackingEnabled ? '1' : '0',
    CacheKeys.globalsStatusStandingRequireAlias:
        Globals.statusStandingRequireAlias ? '1' : '0', // bool
    CacheKeys.globalsTrackPointInterval:
        Globals.trackPointInterval.inSeconds.toString(), // int
    CacheKeys.globalsOsmLookupCondition:
        Globals.osmLookupCondition.name, // String enum name
    CacheKeys.globalsCacheGpsTime:
        Globals.cacheGpsTime.inSeconds.toString(), // int
    CacheKeys.globalsDistanceTreshold:
        Globals.distanceTreshold.toString(), // int
    CacheKeys.globalsTimeRangeTreshold:
        Globals.timeRangeTreshold.inSeconds.toString(), // int
    CacheKeys.globalsAppTickDuration:
        Globals.appTickDuration.inSeconds.toString(), // bool 1|0
    CacheKeys.globalsGpsMaxSpeed: Globals.gpsMaxSpeed.toString(), // int
    CacheKeys.globalsGpsPointsSmoothCount:
        Globals.gpsPointsSmoothCount.toString() // int
  };

  Future<void> saveSettings() async {
    try {
      CacheKeys key;
      key = CacheKeys.globalsBackgroundTrackingEnabled;
      await Cache.setValue<bool>(key, backgroundTrackingEnabled ?? false);

      key = CacheKeys.globalsStatusStandingRequireAlias;
      await Cache.setValue<bool>(key, statusStandingRequireAlias ?? false);

      Duration dur(String? value, Duration defaultValue) {
        if (value == null) {
          return defaultValue;
        }
        return Duration(seconds: int.parse(value));
      }

      key = CacheKeys.globalsTrackPointInterval;
      await Cache.setValue<Duration>(
          key, dur(settings[key], Globals.trackPointInterval));

      key = CacheKeys.globalsOsmLookupCondition;
      await Cache.setValue<OsmLookup>(
          key,
          OsmLookup.values
              .byName(settings[key] ?? Globals.osmLookupCondition.name));

      key = CacheKeys.globalsCacheGpsTime;
      await Cache.setValue<Duration>(
          key, dur(settings[key], Globals.trackPointInterval));

      key = CacheKeys.globalsDistanceTreshold;
      await Cache.setValue<int>(
          key, int.parse(settings[key] ?? Globals.distanceTreshold.toString()));

      key = CacheKeys.globalsTimeRangeTreshold;
      await Cache.setValue<Duration>(
          key, dur(settings[key], Globals.timeRangeTreshold));

      key = CacheKeys.globalsAppTickDuration;
      await Cache.setValue<Duration>(
          key, dur(settings[key], Globals.appTickDuration));

      key = CacheKeys.globalsGpsMaxSpeed;
      await Cache.setValue<int>(
          key, int.parse(settings[key] ?? Globals.gpsMaxSpeed.toString()));

      key = CacheKeys.globalsGpsPointsSmoothCount;
      await Cache.setValue<int>(key,
          int.parse(settings[key] ?? Globals.gpsPointsSmoothCount.toString()));
      await Cache.reload();
      await Globals.loadSettings();
    } catch (e, stk) {
      logger.error('save app settings: $e', stk);
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  ValueNotifier<bool> modified = ValueNotifier<bool>(false);

  void modify() {
    modified.value = true;

    setState(() {});
  }

  void setStatus(BuildContext context, OsmLookup? val) {
    Globals.osmLookupCondition = val ?? OsmLookup.never;
    modified.value = true;
    setState(() {});
  }

  Widget numberField({
    required BuildContext context,
    required TextEditingController controller,
    required CacheKeys cacheKey,
    required int minValue,
    required int maxValue,
    String title = '',
    String description = '',
  }) {
    return Container(
        padding: const EdgeInsets.all(10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Text(title, style: const TextStyle(fontSize: 16))),
          description.trim().isEmpty
              ? const SizedBox.shrink()
              : Container(
                  padding: const EdgeInsets.all(10), child: Text(description)),
          TextField(
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[0-9]')),
            ],
            decoration: InputDecoration(
                label: Text(
                    '$minValue - ${maxValue > 0 ? maxValue : 'unbegrenzt'}',
                    softWrap: true)),
            onChanged: ((value) {
              try {
                int i = int.parse(value);
                if (i < minValue) {
                  i = minValue;
                }
                if (maxValue > 0 && i > maxValue) {
                  i = maxValue;
                }
                settings[cacheKey] = i.toString();
                modify();
              } catch (e) {
                //
              }
            }),
            maxLines: 1, //
            minLines: 1,
            controller: controller,
          )
        ]));
  }

  Widget osmLookup(BuildContext context) {
    List<OsmLookup> list = [
      OsmLookup.always,
      OsmLookup.onStatus,
      OsmLookup.never
    ];
    return DropdownButton<OsmLookup>(
      value: Globals.osmLookupCondition,
      icon: const Icon(Icons.arrow_drop_down),
      style: TextStyle(color: AppColors.black.color),
      onChanged: (OsmLookup? value) {
        // This is called when the user selects an item.
        setState(() {
          Globals.osmLookupCondition = value!;
        });
      },
      items: list.map<DropdownMenuItem<OsmLookup>>((OsmLookup value) {
        String text = '';
        switch (value) {
          case OsmLookup.never:
            text = 'niemals';
            break;
          case OsmLookup.onStatus:
            text = 'Bei Halten/Fahren wechsel';
            break;
          case OsmLookup.always:
            text = 'Bei jedem GPS Interval';
            break;
        }
        return DropdownMenuItem<OsmLookup>(
          value: value,
          child: Text(text),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppWidgets.scaffold(
      context,
      appBar: AppBar(title: const Text('Einstellungen')),
      body: ListView(children: [
        ///
        Container(
            padding: const EdgeInsets.all(5),
            child: ListTile(
              leading: Checkbox(
                  value: statusStandingRequireAlias,
                  onChanged: (bool? b) {
                    statusStandingRequireAlias = b;
                    modify();
                  }),
              title: const Text('Haltepunkt benötigt Alias'),
              subtitle: const Text(
                  'Ein Haltepunkt wird nur gespeichert wenn sie in einem Alias stehen. '
                  'Dies verhindert das speichern von Haltepunkten wenn sie im Stau oder lange an einer Ampel stehen.'),
            )),

        AppWidgets.divider(),

        ///
        Container(
            padding: const EdgeInsets.all(5),
            child: ListTile(
              leading: Checkbox(
                  value: backgroundTrackingEnabled,
                  onChanged: (bool? b) {
                    backgroundTrackingEnabled = b;
                    modify();
                  }),
              title: const Text('Hintergrund GPS aktivieren'),
              subtitle: const Text(
                  'Ob der Hintergrund GPS automatisch starten soll wenn sie die App starten. '
                  'Sollten sie ihn versehentlich abgeschaltet haben, wird er beim nächsten start der app automatisch neu gestartet.'),
            )),

        AppWidgets.divider(),

        ///
        /// trackPointInterval
        numberField(
            context: context,
            controller: txTrackPointInterval ??= TextEditingController(
                text: settings[CacheKeys.globalsTrackPointInterval]),
            cacheKey: CacheKeys.globalsTrackPointInterval,
            minValue: 20,
            maxValue: 0,
            title: 'Hintergrund GPS Interval',
            description:
                'In welchen Zeitabständen in SEKUNDEN das Hintergrung GPS abgefragt wird.\n'
                'Bei Änderungen ist ein Neustart der App Erforderlich.'),

        /// OsmLookup
        Container(
            padding: const EdgeInsets.all(10),
            child: Column(children: [
              const ListTile(
                title: Text('OSM lookup Hintergrundabfrage.'),
                subtitle: Text(
                  'Definiert ob und wann im Hintergrundprozess die Adresse anhand '
                  'der GPS Daten abgefragt wird. Dies ist nur notwendig wenn Haltepunkte '
                  'aufgezeichnet werden können, wo kein Alias ist. Siehe oben: "Haltepunkt benötigt Alias"',
                  softWrap: true,
                ),
              ),
              ListTile(
                  title: Text('Niemals',
                      style: TextStyle(
                        backgroundColor: AppColors.aliasRestricted.color,
                      )),
                  subtitle: const Text(
                    'Die Hintergrundabfrage ist abgeschaltet',
                    softWrap: true,
                  ),
                  leading: Radio<OsmLookup>(
                      value: OsmLookup.never,
                      groupValue: Globals.osmLookupCondition,
                      onChanged: (OsmLookup? val) {
                        settings[CacheKeys.globalsOsmLookupCondition] =
                            val?.name ?? OsmLookup.never.name;
                        setStatus(context, val);
                      })),
              ListTile(
                  title: Text('Bei Statuswechsel',
                      style: TextStyle(
                        backgroundColor: AppColors.aliasPrivate.color,
                      )),
                  subtitle: const Text(
                    'Die Hintergrundabfrage wird nur bei einem Halten/Fahren Statuswechsel ausgeführt.',
                    softWrap: true,
                  ),
                  leading: Radio<OsmLookup>(
                      value: OsmLookup.onStatus,
                      groupValue: Globals.osmLookupCondition,
                      onChanged: (OsmLookup? val) {
                        settings[CacheKeys.globalsOsmLookupCondition] =
                            val?.name ?? OsmLookup.never.name;
                        setStatus(context, val);
                      })),
              ListTile(
                  title: Text('Bei jeder GPS Abfrage',
                      style: TextStyle(
                        backgroundColor: AppColors.aliasPubplic.color,
                      )),
                  subtitle: const Text(
                    'Die OSM Address wird bei jeder "Hintergrund GPS Interval" Abfrage ausgeführt. '
                    'Siehe oben für die Einstellung des Intervals.',
                    softWrap: true,
                  ),
                  leading: Radio<OsmLookup>(
                      value: OsmLookup.always,
                      groupValue: Globals.osmLookupCondition,
                      onChanged: (OsmLookup? val) {
                        settings[CacheKeys.globalsOsmLookupCondition] =
                            val?.name ?? OsmLookup.never.name;
                        setStatus(context, val);
                      }))
            ])),

        /// cacheGpsTime
        numberField(
            context: context,
            controller: txCacheGpsTime ??= TextEditingController(
                text: settings[CacheKeys.globalsCacheGpsTime]),
            cacheKey: CacheKeys.globalsCacheGpsTime,
            minValue: 0,
            maxValue: 0,
            title: 'GPS Cache - Vorhaltezeit',
            description:
                'Stellt ein wie viel Zeit in SEKUNDEN vergehen muss bis das '
                'vorgehaltene Vordergrund GPS verworfen und erneuert wird.'),

        /// distanceTreshold
        numberField(
            context: context,
            controller: txDistanceTrehold ??= TextEditingController(
                text: settings[CacheKeys.globalsDistanceTreshold]),
            cacheKey: CacheKeys.globalsDistanceTreshold,
            minValue: 20,
            maxValue: 0,
            title: 'Distanzschwellwert',
            description:
                'Die Distanz in METER, die sie sich innerhalb von "Zeitschwellwert" (siehe unten) '
                'fortbewegen müssen, um in den Satus Fahren zu wechseln. Oder anders herum '
                'die Distanz, die sie innerhalb von "Zeitschwellwert" unterschreiten müssen, '
                'um in den Status Halten zu wechseln'),

        /// timeRangeTreshold
        numberField(
            context: context,
            controller: txTimeRangeTreshold ??= TextEditingController(
                text: settings[CacheKeys.globalsTimeRangeTreshold]),
            cacheKey: CacheKeys.globalsTimeRangeTreshold,
            minValue: 20,
            maxValue: 0,
            title: 'Zeitschwellwert',
            description:
                'Zur Festellung des Halten/Fahren Status wird für den Zeitraum von "Zeitschwellwert" in SEKUNDEN '
                'die Weg der bis dahin gesammelten GPS Punkte berechnet. Um in den Status Fahren zu wechseln, '
                'müssen sie sich also mit einer gewissen Mindestgeschwindigkeit fortbewegen, die durch die durch die '
                '"Distanzschwellwert" / "Zeitschwellwert" eingestellt werden kann'),

        /// appTickDuration
        numberField(
            context: context,
            controller: txAppTickDuration ??= TextEditingController(
                text: settings[CacheKeys.globalsAppTickDuration]),
            cacheKey: CacheKeys.globalsAppTickDuration,
            minValue: 5,
            maxValue: 0,
            title: 'Live Tracking Aktualisierungsinterval',
            description:
                'Wie oft der Live Tracking Vordergrundprozess nachschaut, '
                'ob der GPS Hintergrundprozess ein neues GPS Signal erstellt '
                'oder einen Statuswechsel festgestellt hat und die Live Tracking Seite '
                'aktualisiert'),

        /// gpsMaxSpeed
        numberField(
            context: context,
            controller: txGpsMaxSpeed ??= TextEditingController(
                text: settings[CacheKeys.globalsGpsMaxSpeed]),
            cacheKey: CacheKeys.globalsGpsMaxSpeed,
            minValue: 5,
            maxValue: 0,
            title: 'Grobe GPS ausrutscher ignorieren',
            description:
                'Bei der GPS Messung kann es zu groben ausrutschern kommen. '
                'Diese Funktion ingnoriert GPS Punkte, die unmöglich in der gegebenen maximimalen '
                'GESCHWINDIGKEIT IN KM/H erreicht werden können.'),

        /// gpsPointsSmoothCount
        numberField(
            context: context,
            controller: txGpsSmoothCount ??= TextEditingController(
                text: settings[CacheKeys.globalsGpsPointsSmoothCount]),
            cacheKey: CacheKeys.globalsGpsPointsSmoothCount,
            minValue: 0,
            maxValue: 0,
            title: 'GPS feine ungenauigkeit kompensieren',
            description:
                'Bei der GPS Messung kann es zu kleinen Ungenauigkeiten kommen. '
                'Diese Funktion berechnet aus der ANZAHL der gegebenen GPS Punkte den Durchschnittswert.'),

        ///
      ]),
      navBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          fixedColor: AppColors.black.color,
          backgroundColor: AppColors.yellow.color,
          items: [
            // 0 alphabethic
            BottomNavigationBarItem(
                icon: ValueListenableBuilder(
                    valueListenable: modified,
                    builder: ((context, value, child) {
                      return Icon(Icons.done,
                          size: 30,
                          color: modified.value == true
                              ? AppColors.green.color
                              : AppColors.white54.color);
                    })),
                label: 'Speichern'),
            // 1 nearest
            const BottomNavigationBarItem(
                icon: Icon(Icons.cancel), label: 'Abbrechen'),
          ],
          onTap: (int id) {
            if (id == 0) {
              bool b = statusStandingRequireAlias ?? false;
              settings[CacheKeys.globalsStatusStandingRequireAlias] =
                  b ? '1' : '0';
              saveSettings().then((_) {
                Fluttertoast.showToast(msg: 'Settings saved');
                Navigator.pop(context);
              });
            } else {
              Navigator.pop(context);
            }
          }),
    );
  }
}
