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

///
import 'package:chaostours/logger.dart';
import 'package:chaostours/conf/app_colors.dart';
import 'package:chaostours/view/app_widgets.dart';
import 'package:chaostours/conf/app_settings.dart';
import 'package:chaostours/cache.dart';
import 'package:chaostours/data_bridge.dart';

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

  bool? statusStandingRequireAlias = AppSettings.statusStandingRequireAlias;
  bool? backgroundTrackingEnabled = AppSettings.backgroundTrackingEnabled;

  TextEditingController txAutocreateAlias = TextEditingController();
  TextEditingController txTrackPointInterval = TextEditingController();
  TextEditingController txAddressLookupInterval = TextEditingController();
  TextEditingController txCacheGpsTime = TextEditingController();
  TextEditingController txDistanceTrehold = TextEditingController();
  TextEditingController txTimeRangeTreshold = TextEditingController();
  TextEditingController txAppTickDuration = TextEditingController();
  TextEditingController txGpsSmoothCount = TextEditingController();
  TextEditingController txGpsMaxSpeed = TextEditingController();

  String selectedCalendar = ' --- ';

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> modify() async {
    await AppSettings.loadSettings();
    setState(() {});
  }

  void setStatus(BuildContext context, OsmLookupConditions? val) {
    AppSettings.osmLookupCondition = val ?? OsmLookupConditions.never;
    setState(() {});
  }

  Widget numberField({
    required BuildContext context,
    required TextEditingController controller,
    required String text,
    required AppSettingLimits limits,
    String title = '',
    String description = '',
  }) {
    if (controller.text != text) {
      controller.text = text;
    }
    String minValue = 'unbegrenzt';
    String maxValue = minValue;

    if (limits.min != null) {
      minValue = (limits.min!).round().toString();
    }
    if (limits.max != null) {
      maxValue = (limits.max!).round().toString();
    }
    return Container(
        padding: const EdgeInsets.all(10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Text(title, style: const TextStyle(fontSize: 16))),
          description.trim().isEmpty
              ? const SizedBox.shrink()
              : Container(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                      '$description${limits.zeroDisables ? '\n\nDer Wert 0 deaktiviert diese Funktion.' : ''}')),
          TextFormField(
            autovalidateMode: AutovalidateMode.always,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[0-9]')),
            ],
            validator: (value) {
              try {
                if (limits.isValid(int.parse(value ?? ''))) {
                  return null;
                }
              } catch (e) {
                //
              }
              return 'Invalid Value';
            },

            decoration: InputDecoration(
                label: Text('$minValue - $maxValue ${limits.unit.name}',
                    softWrap: true)),
            onChanged: ((value) async {
              try {
                if (limits.isValid(int.parse(value))) {
                  AppSettings.updateValue(
                          key: limits.cacheKey,
                          value: int.parse(value) * limits.unit.multiplicator)
                      .then((bool valueChanged) {
                    if (valueChanged) {
                      modify();
                    }
                  });
                }
              } catch (e, stk) {
                logger.error('save globals ${limits.cacheKey.name}: $e', stk);
              }
            }),
            maxLines: 1, //
            minLines: 1,
            controller: controller,
          )
        ]));
  }

  Widget osmLookup(BuildContext context) {
    List<OsmLookupConditions> list = [
      OsmLookupConditions.always,
      OsmLookupConditions.onStatusChanged,
      OsmLookupConditions.onCreateAlias,
      OsmLookupConditions.never
    ];
    return DropdownButton<OsmLookupConditions>(
      value: AppSettings.osmLookupCondition,
      icon: const Icon(Icons.arrow_drop_down),
      style: TextStyle(color: AppColors.black.color),
      onChanged: (OsmLookupConditions? value) {
        // This is called when the user selects an item.
        value ??= OsmLookupConditions.never;
        AppSettings.updateValue(
                key: Cache.appSettingOsmLookupCondition, value: value)
            .then((_) {
          AppSettings.osmLookupCondition = value!;
          modify();
        });
        setState(() {
          AppSettings.osmLookupCondition = value ?? OsmLookupConditions.never;
        });
      },
      items: list.map<DropdownMenuItem<OsmLookupConditions>>(
          (OsmLookupConditions value) {
        String text = '';
        switch (value) {
          case OsmLookupConditions.never:
            text = 'Niemals';
            break;
          case OsmLookupConditions.onCreateAlias:
            text = 'Bei automatischer Alias Erstellung';
            break;
          case OsmLookupConditions.onStatusChanged:
            text = 'Bei Halten/Fahren wechsel';
            break;
          case OsmLookupConditions.always:
            text = 'Bei jedem GPS Interval';
            break;
        }
        return DropdownMenuItem<OsmLookupConditions>(
          value: value,
          child: Text(text),
        );
      }).toList(),
    );
  }

  Future<bool> load() async {
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: load(),
      builder: (context, snapshot) {
        return AppWidgets.checkSnapshot(context, snapshot) ?? _build(context);
      },
    );
  }

  Widget _build(BuildContext context) {
    return AppWidgets.scaffold(context,
        appBar: AppBar(title: const Text('Einstellungen')),
        body: ListView(children: [
          ///
          const Center(
              child: Text('\n\nAlias (Orte)',
                  style: TextStyle(fontWeight: FontWeight.bold))),
          AppWidgets.divider(),

          Container(
              padding: const EdgeInsets.all(5),
              child: ListTile(
                leading: Checkbox(
                    value: AppSettings.statusStandingRequireAlias,
                    onChanged: (bool? b) async {
                      b ??= false;
                      await AppSettings.updateValue(
                          key: Cache.appSettingStatusStandingRequireAlias,
                          value: b);
                      //await AppSettings.loadSettings();
                      modify();
                    }),
                title: const Text('Haltepunkt benötigt Alias'),
                subtitle: const Text(
                    'Ein Haltepunkt wird nur gespeichert wenn sie in einem Alias stehen. '
                    'Dies verhindert das speichern von Haltepunkten wenn sie im Stau oder lange an einer Ampel stehen.'),
              )),

          AppWidgets.divider(),

          ///
          /// autocreate alias
          numberField(
              context: context,
              controller: txAutocreateAlias,
              text: AppSettings.autoCreateAlias.inMinutes.toString(),
              limits: AppSettings.autoCreateAliasLimits, // minutes to seconds
              title: 'Alias automatisch erstellen',
              description:
                  'Nach wie viel MINUTEN Standzeit ein Alias automatisch erstellt wird.\n'
                  'Bitte beachten sie dass sich alle ${DataBridge().calcGpsPoints.length} blauen GPS Berechnungspunkte '
                  'im ${AppSettings.distanceTreshold}m radius des Distanzschwellwertes befinden müssen, '
                  'um sie eindeutig als "vor Ort" identifizieren zu können.'),

          const Center(
              child: Text('\n\n\nHintergrund GPS Verarbeitung',
                  style: TextStyle(fontWeight: FontWeight.bold))),
          AppWidgets.divider(),

          /// backgroundTrackingEnabled
          Container(
              padding: const EdgeInsets.all(5),
              child: ListTile(
                leading: Checkbox(
                    value: AppSettings.backgroundTrackingEnabled,
                    onChanged: (bool? b) {
                      b ??= false;
                      AppSettings.updateValue(
                              key: Cache.appSettingBackgroundTrackingEnabled,
                              value: b)
                          .then((_) {
                        AppSettings.backgroundTrackingEnabled = b!;
                        modify();
                      });
                    }),
                title: const Text('Hintergrund GPS aktivieren'),
                subtitle: const Text(
                    'Ob der Hintergrund GPS automatisch starten soll wenn die App startet. '
                    'Sollten sie ihn versehentlich abgeschaltet haben, wird er beim nächsten start der app automatisch neu gestartet.'),
              )),

          AppWidgets.divider(),

          ///
          /// trackPointInterval
          numberField(
              context: context,
              controller: txTrackPointInterval,
              text: AppSettings.trackPointInterval.inSeconds.toString(),
              limits: AppSettings.trackPointIntervalLimits,
              title: 'Hintergrund GPS Interval',
              description:
                  'In welchen Zeitabständen in SEKUNDEN das Hintergrung GPS abgefragt wird.\n'
                  'Bei Änderungen ist ein Neustart der App Erforderlich.'),

          /// distanceTreshold
          numberField(
              context: context,
              controller: txDistanceTrehold,
              text: AppSettings.distanceTreshold.toString(),
              limits: AppSettings.distanceTresholdLimits,
              title: 'Distanzschwellwert',
              description:
                  'Die Distanz in METER, die sie sich innerhalb von "Zeitschwellwert" (siehe unten) '
                  'fortbewegen müssen, um in den Satus Fahren zu wechseln. Oder anders herum '
                  'die Distanz, die sie innerhalb von "Zeitschwellwert" unterschreiten müssen, '
                  'um in den Status Halten zu wechseln'),

          /// timeRangeTreshold
          numberField(
              context: context,
              controller: txTimeRangeTreshold,
              text: AppSettings.timeRangeTreshold.inMinutes.toString(),
              limits: AppSettings.timeRangeTresholdLimits, // minutes to seconds
              title: 'Zeitschwellwert',
              description:
                  'Zur Festellung des Halten/Fahren Status wird für den Zeitraum von "Zeitschwellwert" in MINUTEN '
                  'der Weg der bis dahin gesammelten GPS Punkte berechnet. Um in den Status Fahren zu wechseln, '
                  'müssen sie sich also mit einer gewissen Mindestgeschwindigkeit fortbewegen, die durch die durch die '
                  '"Distanzschwellwert" / "Zeitschwellwert" eingestellt werden kann'),

          /// gpsPointsSmoothCount
          numberField(
              context: context,
              controller: txGpsSmoothCount,
              text: AppSettings.gpsPointsSmoothCount.toString(),
              limits: AppSettings.gpsPointsSmoothCountLimits,
              title: 'GPS smoothing',
              description:
                  'Bei der GPS Messung kann es zu kleinen Ungenauigkeiten kommen. '
                  'Diese Funktion berechnet aus der ANZAHL der gegebenen GPS Punkte den Durchschnittswert. '),

          const Center(
              child: Text('\n\n\nOpen Street Map',
                  style: TextStyle(fontWeight: FontWeight.bold))),
          AppWidgets.divider(),

          /// OsmLookup
          Container(
              padding: const EdgeInsets.all(10),
              child: Column(children: [
                const ListTile(
                  title: Text('OSM lookup Hintergrundabfrage.'),
                  subtitle: Text(
                    'Diese Funktion verbraucht etwa 1KB Online-Daten pro Abfrage beim kostenlosen Service von OpenStreetMap.com',
                    softWrap: true,
                  ),
                ),
                ListTile(
                    title: const Text('Niemals'),
                    subtitle: const Text(
                      'Die Hintergrundabfrage ist abgeschaltet',
                      softWrap: true,
                    ),
                    leading: Radio<OsmLookupConditions>(
                        value: OsmLookupConditions.never,
                        groupValue: AppSettings.osmLookupCondition,
                        onChanged: (OsmLookupConditions? val) {
                          if (val != null) {
                            AppSettings.updateValue(
                                key: Cache.appSettingOsmLookupCondition,
                                value: val);
                          }
                          setStatus(context, val);
                        })),
                ListTile(
                    title: const Text('Bei Statuswechsel'),
                    subtitle: const Text(
                      'Die Hintergrundabfrage wird nur bei einem Halten/Fahren Statuswechsel ausgeführt.',
                      softWrap: true,
                    ),
                    leading: Radio<OsmLookupConditions>(
                        value: OsmLookupConditions.onStatusChanged,
                        groupValue: AppSettings.osmLookupCondition,
                        onChanged: (OsmLookupConditions? val) {
                          if (val != null) {
                            AppSettings.updateValue(
                                key: Cache.appSettingOsmLookupCondition,
                                value: val);
                          }
                          setStatus(context, val);
                        })),
                ListTile(
                    title: const Text('Bei jeder GPS Abfrage'),
                    subtitle: Text(
                      'Die OSM Address wird bei jeder "Hintergrund GPS Interval" Abfrage ausgeführt. '
                      'Bei dem gegenwärtig eingestellten Hintergrund GPS Interval von ${AppSettings.trackPointInterval.inSeconds}sec. sollten sie mit einem Datenverbrauch von etwa '
                      '${(3600 / AppSettings.trackPointInterval.inSeconds * 24 / 1024).ceil()}MB/Tag rechnen. ',
                      softWrap: true,
                    ),
                    leading: Radio<OsmLookupConditions>(
                        value: OsmLookupConditions.always,
                        groupValue: AppSettings.osmLookupCondition,
                        onChanged: (OsmLookupConditions? val) {
                          if (val != null) {
                            AppSettings.updateValue(
                                key: Cache.appSettingOsmLookupCondition,
                                value: val);
                          }
                          setStatus(context, val);
                        }))
              ])),

          /// publishToCalendar
          const Center(
              child: Text('\n\n\nKalender',
                  style: TextStyle(fontWeight: FontWeight.bold))),
          AppWidgets.divider(),

          Container(
              padding: const EdgeInsets.all(5),
              child: ListTile(
                leading: Checkbox(
                    value: AppSettings.publishToCalendar,
                    onChanged: (bool? b) {
                      b ??= false;
                      AppSettings.updateValue(
                              key: Cache.appSettingPublishToCalendar, value: b)
                          .then((_) {
                        AppSettings.publishToCalendar = b!;
                        modify();
                      });
                    }),
                title: const Text('Gerätekalender verwenden'),
                subtitle: const Text(
                    'Haltepunkte in einen Kalender ihres Gerätes schreiben. '
                    'Diese Funktion gibt ihnen die Möglichkeit ihre Haltepunkte über ihren Kalender mit anderen zu teilen. '
                    'So können sie ihre Mitarbeiter, Freunde oder Familienangehörige stets wissen lassen wo sie gerade sind '
                    'oder was sie am besuchten Ort gemacht haben.'),
              )),

          AppWidgets.divider(),

          const Center(
              child: Text('\n\n\nGPS',
                  style: TextStyle(fontWeight: FontWeight.bold))),
          AppWidgets.divider(),

          /// cacheGpsTime
          numberField(
              context: context,
              controller: txCacheGpsTime,
              text: AppSettings.cacheGpsTime.inSeconds.toString(),
              limits: AppSettings.cachGpsTimeLimits,
              title: 'GPS Cache - Vorhaltezeit',
              description:
                  'Stellt ein wie viel Zeit in SEKUNDEN vergehen muss bis das '
                  'vorgehaltene Vordergrund GPS verworfen und erneuert wird.'),

          const Center(
              child: Text('\n\n\nHUD Framerate',
                  style: TextStyle(fontWeight: FontWeight.bold))),
          AppWidgets.divider(),

          /// appTickDuration
          numberField(
              context: context,
              controller: txAppTickDuration,
              text: AppSettings.backgroundLookupDuration.inSeconds.toString(),
              limits: AppSettings.backgroundLookupDurationLimits,
              title: 'Live Tracking Aktualisierungsinterval',
              description:
                  'Wie oft der Live Tracking Vordergrundprozess nachschaut, '
                  'ob der GPS Hintergrundprozess ein neues GPS Signal erstellt '
                  'oder einen Statuswechsel festgestellt hat und die Live Tracking Seite '
                  'aktualisiert'),

          /// reset options
          const Center(
              child: Text('\n\n\nReset',
                  style: TextStyle(fontWeight: FontWeight.bold))),
          AppWidgets.divider(),
          Padding(
              padding: const EdgeInsets.all(10),
              child: ElevatedButton(
                  onPressed: () async {
                    await AppSettings.reset();
                    modify();
                  },
                  child: const Text('Einstellungen zurücksetzen'))),

          /// style switch
          const Center(
              child:
                  Text('\n\n', style: TextStyle(fontWeight: FontWeight.bold))),

          ///
        ]),
        navBar: null);
  }
}
