import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:chaostours/globals.dart';
import 'package:chaostours/view/app_widgets.dart';
import 'package:chaostours/cache.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/model/model_user.dart';
import 'package:chaostours/checkbox_controller.dart';
import 'package:chaostours/app_settings.dart';

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
  TextEditingController? txWaitTimeAfterStatusChanged;
  TextEditingController? txAppTickDuration;
  TextEditingController? txGpsSmoothCount;
  TextEditingController? txGpsMaxSpeed;

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
    required AppSettings sharedKey,
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
                AppSettings.settings[sharedKey] = i.toString();
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
                text: AppSettings.settings[AppSettings.trackPointInterval]),
            sharedKey: AppSettings.trackPointInterval,
            minValue: 20,
            maxValue: 0,
            title: 'Hintergrund GPS Interval',
            description:
                'In welchen Zeitabständen in SEKUNDEN das Hintergrung GPS abgefragt wird.\n'
                'Bei Änderungen ist ein Neustart der App Erforderlich.'),

        /// addressLookupInterval
        numberField(
            context: context,
            controller: txAddressLookupInterval ??= TextEditingController(
                text: AppSettings.settings[AppSettings.addressLookupInterval]),
            sharedKey: AppSettings.addressLookupInterval,
            minValue: 10,
            maxValue: 0,
            title: 'Live Tracking OSM Adress lookup Interval',
            description:
                'In welchen Zeitabständen in MINUTEN beim kostenlosen Service von OpenStreetMap.com '
                'anhand der GPS Daten die Adresse abgefragt werden.\n'
                'Dieser Wert sollte nicht niedriger als der GPS Hintergrund Interval sein.\n'
                'Eine einzelne Online Abfrage verbraucht etwa 1kb Mobile Daten.\nDer mindestwert ist zwar 10 Sekunden,'
                ' sie können aber mit 0 Sekunden die Funktion abschalten'),

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
                        AppSettings.settings[AppSettings.osmLookupCondition] =
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
                        AppSettings.settings[AppSettings.osmLookupCondition] =
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
                        AppSettings.settings[AppSettings.osmLookupCondition] =
                            val?.name ?? OsmLookup.never.name;
                        setStatus(context, val);
                      }))
            ])),

        /// cacheGpsTime
        numberField(
            context: context,
            controller: txCacheGpsTime ??= TextEditingController(
                text: AppSettings.settings[AppSettings.cacheGpsTime]),
            sharedKey: AppSettings.cacheGpsTime,
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
                text: AppSettings.settings[AppSettings.distanceTreshold]),
            sharedKey: AppSettings.distanceTreshold,
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
                text: AppSettings.settings[AppSettings.timeRangeTreshold]),
            sharedKey: AppSettings.timeRangeTreshold,
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
                text: AppSettings.settings[AppSettings.appTickDuration]),
            sharedKey: AppSettings.appTickDuration,
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
                text: AppSettings.settings[AppSettings.gpsMaxSpeed]),
            sharedKey: AppSettings.gpsMaxSpeed,
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
                text: AppSettings.settings[AppSettings.gpsPointsSmoothCount]),
            sharedKey: AppSettings.gpsPointsSmoothCount,
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
              AppSettings.settings[AppSettings.statusStandingRequireAlias] =
                  b ? '1' : '0';
              AppSettings.updateGlobals();
              AppSettings.saveToShared().then((_) {
                Navigator.pop(context);
              });
            } else {
              Navigator.pop(context);
            }
          }),
    );
  }
}