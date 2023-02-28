import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:chaostours/globals.dart';
import 'package:chaostours/view/app_widgets.dart';
import 'package:chaostours/shared.dart';
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

  Map<AppSettings, String> settings = AppSettings.settings;

  bool? statusStandingRequireAlias = Globals.statusStandingRequireAlias;

  ValueNotifier<bool> modified = ValueNotifier<bool>(false);

  @override
  void dispose() {
    super.dispose();
  }

  void modify() {
    if (!modified.value) {
      modified.value = true;
      setState(() {});
    }
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
                settings[sharedKey] = i.toString();
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

  /// render multiple checkboxes
  Widget createCheckbox(CheckboxController model) {
    TextStyle style = TextStyle(
        color: model.enabled ? Colors.black : Colors.grey,
        decoration:
            model.deleted ? TextDecoration.lineThrough : TextDecoration.none);

    return ListTile(
      subtitle: model.subtitle.trim().isEmpty
          ? null
          : Text(model.subtitle, style: const TextStyle(color: Colors.grey)),
      title: Text(
        model.title,
        style: style,
      ),
      leading: Checkbox(
        value: model.checked,
        onChanged: (_) {
          setState(
            () {
              model.handler()?.call();
            },
          );
        },
      ),
      onTap: () {
        setState(
          () {
            model.handler()?.call();
          },
        );
      },
    );
  }

  List<Widget> userCheckboxes(context) {
    var referenceList = Globals.preselectedUsers;
    var checkBoxes = <Widget>[];
    for (var tp in ModelUser.getAll()) {
      if (!tp.deleted) {
        checkBoxes.add(createCheckbox(CheckboxController(
            idReference: tp.id,
            referenceList: referenceList,
            deleted: tp.deleted,
            title: tp.user,
            subtitle: tp.notes)));
      }
    }
    return checkBoxes;
  }

  bool dropdownUserIsOpen = false;
  Widget dropdownUser(context) {
    /// render selected users
    List<String> userList = ModelUser.getAll().map((e) => e.user).toList();
    String users =
        userList.isNotEmpty ? '- ${userList.join('\n- ')}' : 'Keine Ausgewählt';

    /// dropdown menu botten with selected users
    List<Widget> items = [
      ElevatedButton(
        child: ListTile(trailing: const Icon(Icons.menu), title: Text(users)),
        onPressed: () {
          dropdownUserIsOpen = !dropdownUserIsOpen;
          setState(() {});
        },
      ),
      !dropdownUserIsOpen
          ? const SizedBox.shrink()
          : Column(children: userCheckboxes(context))
    ];
    return ListBody(children: items);
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
        Center(
            child: Container(
                padding: const EdgeInsets.all(20),
                child: const Text('Vorausgewähltes Personal',
                    style: TextStyle(fontSize: 16)))),
        Container(child: dropdownUser(context)),
        Container(
            padding: const EdgeInsets.all(5), child: AppWidgets.divider()),

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
        /// trackPointInterval
        numberField(
            context: context,
            controller: TextEditingController(
                text: settings[AppSettings.trackPointInterval]),
            sharedKey: AppSettings.trackPointInterval,
            minValue: 20,
            maxValue: 0,
            title: 'Hintergrund GPS Interval',
            description:
                'In welchen Zeitabständen in Sekunden das Hintergrung GPS abgefragt wird.\n'
                'Bei Änderungen ist ein Neustart der App Erforderlich.'),

        ///
        numberField(
            context: context,
            controller: TextEditingController(
                text: settings[AppSettings.addressLookupInterval]),
            sharedKey: AppSettings.addressLookupInterval,
            minValue: 10,
            maxValue: 0,
            title: 'Live Tracking OSM Adress lookup Interval',
            description:
                'In welchen Zeitabständen in Sekunden bei OpenStreetMap.com anhand der GPS Daten die Adresse abgefragt wird.\n'
                'Dieser Wert sollte nicht niedriger als der GPS Hintergrund Interval sein.\n'
                'Die Online Abfrage verbraucht etwa 1kb Daten. Der mindestwert ist zwar 10 Sekunden,'
                ' sie können aber auch mit 0 Sekunden die Funktion abschalten'),

        ///
        Container(
            padding: const EdgeInsets.all(10),
            child: Column(children: [
              const ListTile(
                title: Text('OSM lookup Hintergrundabfrage.'),
                subtitle: Text(
                  'Definiert ob und wann im Hintergrundprozess die Adresse anhand '
                  'der GPS Daten abgefragt werden.',
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
                        settings[AppSettings.osmLookupCondition] =
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
                        settings[AppSettings.osmLookupCondition] =
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
                        settings[AppSettings.osmLookupCondition] =
                            val?.name ?? OsmLookup.never.name;
                        setStatus(context, val);
                      }))
            ])),

        ///cacheGpsTime
        numberField(
            context: context,
            controller:
                TextEditingController(text: settings[AppSettings.cacheGpsTime]),
            sharedKey: AppSettings.cacheGpsTime,
            minValue: 0,
            maxValue: 0,
            title: 'GPS Cache - Vorhaltezeit',
            description:
                'Stellt ein wie viel Zeit in Sekunden vergehen muss bis das '
                'vorgehaltene Vordergrund GPS verworfen und erneuert wird.'),

        ///
        numberField(
            context: context,
            controller: TextEditingController(
                text: settings[AppSettings.distanceTreshold]),
            sharedKey: AppSettings.distanceTreshold,
            minValue: 20,
            maxValue: 0,
            title: 'Distanzschwellwert',
            description:
                'Die Distanz in Meter, die sie sich innerhalb von "Zeitschwellwert" (siehe unten) '
                'fortbewegen müssen, um in den Satus Fahren zu wechseln. Oder anders herum '
                'die Distanz, die sie innerhalb von "Zeitschwellwert" unterschreiten müssen, '
                'um in den Status Halten zu wechseln'),

        numberField(
            context: context,
            controller: TextEditingController(
                text: settings[AppSettings.timeRangeTreshold]),
            sharedKey: AppSettings.timeRangeTreshold,
            minValue: 20,
            maxValue: 0,
            title: 'Zeitschwellwert',
            description:
                'Zur Festellung des Halten/Fahren Status wird für den Zeitraum von "Zeitschwellwert" in Sekunden '
                'die Weg der bis dahin gesammelten GPS Punkte berechnet. Um in den Status Fahren zu wechseln, '
                'müssen sie sich also mit einer gewissen Mindestgeschwindigkeit fortbewegen, die durch die durch die '
                '"Distanzschwellwert" / "Zeitschwellwert" eingestellt werden kann'),

        numberField(
            context: context,
            controller: TextEditingController(
                text: settings[AppSettings.waitTimeAfterStatusChanged]),
            sharedKey: AppSettings.waitTimeAfterStatusChanged,
            minValue: 0,
            maxValue: 0,
            title: 'Wartezeit nach Statuswechsel',
            description:
                'Die Zeit in Sekunden, in der nach einem Statuswechsel die GPS Hintergrund Berechnungen pausieren.'),

        numberField(
            context: context,
            controller: TextEditingController(
                text: settings[AppSettings.appTickDuration]),
            sharedKey: AppSettings.appTickDuration,
            minValue: 5,
            maxValue: 0,
            title: 'Live Tracking Aktualisierungsinterval',
            description:
                'Wie oft der Live Tracking Vordergrundprozess nachschaut, '
                'ob der GPS Hintergrundprozess ein neues GPS Signal erstellt '
                'oder einen Statuswechsel festgestellt hat und die Live Tracking Seite '
                'aktualisiert'),

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
              AppSettings.settings[AppSettings.statusStandingRequireAlias] =
                  (statusStandingRequireAlias ?? false) ? '1' : '0';
              AppSettings.update();
              AppSettings.save().then((_) {
                Navigator.pop(context);
              });
            } else {
              Navigator.pop(context);
            }
          }),
    );
  }
}
