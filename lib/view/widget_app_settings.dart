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

import 'package:chaostours/conf/app_settings.dart';
import 'package:chaostours/conf/app_colors.dart';
import 'package:chaostours/conf/app_routes.dart';
import 'package:chaostours/calendar.dart';
import 'package:device_calendar/device_calendar.dart';
import 'package:chaostours/conf/osm.dart';
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

  bool? statusStandingRequireAlias = AppSettings.statusStandingRequireAlias;
  bool? backgroundTrackingEnabled = AppSettings.backgroundTrackingEnabled;

  TextEditingController? txAutocreateAlias;
  TextEditingController? txTrackPointInterval;
  TextEditingController? txAddressLookupInterval;
  TextEditingController? txCacheGpsTime;
  TextEditingController? txDistanceTrehold;
  TextEditingController? txTimeRangeTreshold;
  TextEditingController? txAppTickDuration;
  TextEditingController? txGpsSmoothCount;
  TextEditingController? txGpsMaxSpeed;

  String selectedCalendar = ' --- ';

  @override
  void initState() {
    super.initState();
    getCalendarId();
  }

  Future<void> getCalendarId() async {
    var appCalendar = AppCalendar();
    appCalendar.retrieveCalendars().then((data) async {
      Calendar? calendar = await appCalendar.getCalendarfromCacheId();
      if (calendar != null) {
        selectedCalendar =
            '#${calendar.id}: ${calendar.name}\n<${calendar.accountName}>';
      }
      if (mounted) {
        setState(() {});
      }
    });
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

  Widget numberField(
      {required BuildContext context,
      required TextEditingController controller,
      required CacheKeys cacheKey,
      required int minValue,
      required int maxValue,
      String title = '',
      String unit = '',
      String description = '',
      int multiplicator = 1}) {
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
                    '$minValue - ${maxValue > 0 ? maxValue : 'unbegrenzt'} $unit',
                    softWrap: true)),
            onChanged: ((value) async {
              try {
                int i = int.parse(value);
                if (i < minValue) {
                  i = minValue;
                }
                if (maxValue > 0 && i > maxValue) {
                  i = maxValue;
                }
                i *= multiplicator;
                Type type = cacheKey.cacheType;
                await AppSettings.updateValue(
                    key: cacheKey, type: type, value: i);
                modify();
              } catch (e, stk) {
                logger.error('save globals ${cacheKey.name}: $e', stk);
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
      OsmLookupConditions.onStatus,
      OsmLookupConditions.never
    ];
    return DropdownButton<OsmLookupConditions>(
      value: AppSettings.osmLookupCondition,
      icon: const Icon(Icons.arrow_drop_down),
      style: TextStyle(color: AppColors.black.color),
      onChanged: (OsmLookupConditions? value) {
        // This is called when the user selects an item.
        setState(() {
          AppSettings.osmLookupCondition = value ?? OsmLookupConditions.never;
        });
      },
      items: list.map<DropdownMenuItem<OsmLookupConditions>>(
          (OsmLookupConditions value) {
        String text = '';
        switch (value) {
          case OsmLookupConditions.never:
            text = 'niemals';
            break;
          case OsmLookupConditions.onStatus:
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

  @override
  Widget build(BuildContext context) {
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
                    onChanged: (bool? b) {
                      AppSettings.statusStandingRequireAlias = b ?? false;
                      modify();
                    }),
                title: const Text('Haltepunkt benötigt Alias'),
                subtitle: const Text(
                    'Ein Haltepunkt wird nur gespeichert wenn sie in einem Alias stehen. '
                    'Dies verhindert das speichern von Haltepunkten wenn sie im Stau oder lange an einer Ampel stehen.'),
              )),

          AppWidgets.divider(),

          ///
          /// trackPointInterval
          numberField(
              context: context,
              controller: txAutocreateAlias ??= TextEditingController(
                  text: AppSettings.autoCreateAlias.inMinutes.toString()),
              cacheKey: CacheKeys.globalsAutocreateAlias,
              minValue: AppSettings.autoCreateAliasLimits.min ?? 0,
              maxValue: AppSettings.autoCreateAliasLimits.max ?? 0,
              unit: 'minuten',
              multiplicator: 60, // minutes to seconds
              title: 'Alias automatisch erstellen',
              description:
                  'Nach wie viel MINUTEN Standzeit ein Alias automatisch erstellt wird.\n'
                  'Bitte beachten sie dass sich alle ${DataBridge().calcGpsPoints.length} blauen GPS Berechnungspunkte '
                  'im ${AppSettings.distanceTreshold}m radius des Distanzschwellwertes befinden müssen, '
                  'um sie eindeutig als "vor Ort" identifizieren zu können.\n'
                  'Der Wert 0 deativiert die Funktion.'),

          const Center(
              child: Text('\n\n\nHintergrund GPS Verarbeitung',
                  style: TextStyle(fontWeight: FontWeight.bold))),
          AppWidgets.divider(),

          ///
          Container(
              padding: const EdgeInsets.all(5),
              child: ListTile(
                leading: Checkbox(
                    value: AppSettings.backgroundTrackingEnabled,
                    onChanged: (bool? b) {
                      AppSettings.backgroundTrackingEnabled = b ?? false;
                      modify();
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
              controller: txTrackPointInterval ??= TextEditingController(
                  text: AppSettings.trackPointInterval.inSeconds.toString()),
              cacheKey: CacheKeys.globalsTrackPointInterval,
              minValue: AppSettings.trackingIntervalLimits.min ?? 0,
              maxValue: AppSettings.trackingIntervalLimits.max ?? 0,
              unit: 'sekunden',
              title: 'Hintergrund GPS Interval',
              description:
                  'In welchen Zeitabständen in SEKUNDEN das Hintergrung GPS abgefragt wird.\n'
                  'Bei Änderungen ist ein Neustart der App Erforderlich.'),

          /// distanceTreshold
          numberField(
              context: context,
              controller: txDistanceTrehold ??= TextEditingController(
                  text: AppSettings.distanceTreshold.toString()),
              cacheKey: CacheKeys.globalsDistanceTreshold,
              minValue: AppSettings.distanceTresholdLimits.min ?? 0,
              maxValue: AppSettings.distanceTresholdLimits.max ?? 0,
              unit: 'meter',
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
                  text: AppSettings.timeRangeTreshold.inMinutes.toString()),
              cacheKey: CacheKeys.globalsTimeRangeTreshold,
              minValue:
                  ((AppSettings.timeRangeTresholdLimits.min ?? 0) / 60).round(),
              maxValue:
                  ((AppSettings.timeRangeTresholdLimits.max ?? 0) / 60).round(),
              unit: 'minuten',
              multiplicator: 60, // minutes to seconds
              title: 'Zeitschwellwert',
              description:
                  'Zur Festellung des Halten/Fahren Status wird für den Zeitraum von "Zeitschwellwert" in MINUTEN '
                  'der Weg der bis dahin gesammelten GPS Punkte berechnet. Um in den Status Fahren zu wechseln, '
                  'müssen sie sich also mit einer gewissen Mindestgeschwindigkeit fortbewegen, die durch die durch die '
                  '"Distanzschwellwert" / "Zeitschwellwert" eingestellt werden kann'),

          /// gpsPointsSmoothCount
          numberField(
              context: context,
              controller: txGpsSmoothCount ??= TextEditingController(
                  text: AppSettings.gpsPointsSmoothCount.toString()),
              cacheKey: CacheKeys.globalsGpsPointsSmoothCount,
              minValue: AppSettings.gpsPointsSmoothCountLimits.min ?? 0,
              maxValue: AppSettings.gpsPointsSmoothCountLimits.max ?? 0,
              unit: 'stück',
              title: 'GPS smoothing',
              description:
                  'Bei der GPS Messung kann es zu kleinen Ungenauigkeiten kommen. '
                  'Diese Funktion berechnet aus der ANZAHL der gegebenen GPS Punkte den Durchschnittswert. '
                  'Der Wert 0 deaktiviert diese Funktion'),

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
                            AppSettings.osmLookupCondition = val;
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
                        value: OsmLookupConditions.onStatus,
                        groupValue: AppSettings.osmLookupCondition,
                        onChanged: (OsmLookupConditions? val) {
                          if (val != null) {
                            AppSettings.osmLookupCondition = val;
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
                            AppSettings.osmLookupCondition = val;
                          }
                          setStatus(context, val);
                        }))
              ])),

          ///
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
                      AppSettings.publishToCalendar = b ?? false;
                      modify();
                    }),
                title: const Text('Gerätekalender verwenden'),
                subtitle: const Text(
                    'Haltepunkte in einen Kalender ihres Gerätes schreiben. '
                    'Diese Funktion gibt ihnen die Möglichkeit ihre Haltepunkte über ihren Kalender mit anderen zu teilen. '
                    'So können sie ihre Mitarbeiter, Freunde oder Familienangehörige stets wissen lassen wo sie gerade sind '
                    'oder was sie am besuchten Ort gemacht haben.'),
              )),
          Padding(
              padding: const EdgeInsets.all(10),
              child: ElevatedButton(
                  style: ButtonStyle(alignment: Alignment.centerLeft),
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.selectCalendar.route)
                        .then((_) {
                      getCalendarId();
                    });
                  },
                  child: Padding(
                      padding: EdgeInsets.all(5),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Kalender auswählen. Aktuell:\n'),
                          Text(selectedCalendar)
                        ],
                      )))),

          AppWidgets.divider(),
          const Center(
              child: Text('\n\n\nGPS',
                  style: TextStyle(fontWeight: FontWeight.bold))),
          AppWidgets.divider(),

          /// cacheGpsTime
          numberField(
              context: context,
              controller: txCacheGpsTime ??= TextEditingController(
                  text: AppSettings.cacheGpsTime.inSeconds.toString()),
              cacheKey: CacheKeys.globalsCacheGpsTime,
              minValue: AppSettings.cachGpsTimeLimits.min ?? 0,
              maxValue: AppSettings.cachGpsTimeLimits.max ?? 0,
              unit: 'sekunden',
              title: 'GPS Cache - Vorhaltezeit',
              description:
                  'Stellt ein wie viel Zeit in SEKUNDEN vergehen muss bis das '
                  'vorgehaltene Vordergrund GPS verworfen und erneuert wird. '
                  'Der Wert 0 deaktiviert diese Funktion.Default'),

          const Center(
              child: Text('\n\n\nHUD Framerate',
                  style: TextStyle(fontWeight: FontWeight.bold))),
          AppWidgets.divider(),

          /// appTickDuration
          numberField(
              context: context,
              controller: txAppTickDuration ??= TextEditingController(
                  text: AppSettings.backgroundLookupDuration.inSeconds
                      .toString()),
              cacheKey: CacheKeys.globalsAppTickDuration,
              minValue: AppSettings.backgroundLookupDurationLimits.min ?? 0,
              maxValue: AppSettings.backgroundLookupDurationLimits.max ?? 0,
              unit: 'sekunden',
              title: 'Live Tracking Aktualisierungsinterval',
              description:
                  'Wie oft der Live Tracking Vordergrundprozess nachschaut, '
                  'ob der GPS Hintergrundprozess ein neues GPS Signal erstellt '
                  'oder einen Statuswechsel festgestellt hat und die Live Tracking Seite '
                  'aktualisiert'),

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

          const Center(
              child:
                  Text('\n\n', style: TextStyle(fontWeight: FontWeight.bold))),

          ///
        ]),
        navBar: null);
  }
}
