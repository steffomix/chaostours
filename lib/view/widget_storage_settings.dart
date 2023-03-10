import 'package:flutter/material.dart';
import 'package:external_path/external_path.dart';
import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart' as pp;

///
import 'package:chaostours/file_handler.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/globals.dart';
import 'package:chaostours/shared.dart';
import 'package:chaostours/view/app_widgets.dart';
import 'package:chaostours/shared.dart';
import 'package:confirm_dialog/confirm_dialog.dart';

class WidgetStorageSettings extends StatefulWidget {
  const WidgetStorageSettings({super.key});

  @override
  State<WidgetStorageSettings> createState() => _WidgetStorageSettings();
}

class _WidgetStorageSettings extends State<WidgetStorageSettings> {
  static final Logger logger = Logger.logger<WidgetStorageSettings>();

  final Map<Storages, String?> storages = FileHandler.storages;

  Storages selectedStorage = FileHandler.storageKey;

  bool loading = true;

  ValueNotifier<bool> modified = ValueNotifier<bool>(false);
  bool confirmRequired = false;
  bool corruptedSettings = false;

  void modify() {
    modified.value = true;
    setState(() {});
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void initState() {
    /// basic and fallback setting
    selectedStorage = FileHandler.storageKey;

    loading = false;
    setState(() {});
    super.initState();
  }

  Future<void> createDir(String path, Storages target) async {
    Directory dir = Directory(path);
    if (!dir.existsSync()) {
      // thows exception
      dir = await dir.create(recursive: true);
      storages[target] = dir.path;
      logger.log(dir.path);
    } else {
      storages[target] = dir.path;
      logger.log(dir.path);
    }
  }

  void setStorage(BuildContext context, Storages storage) {
    selectedStorage = storage;
    modify();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return AppWidgets.scaffold(context,
          body: Center(child: AppWidgets.loading()));
    }
    List<Widget> options = [];

    if (corruptedSettings) {
      options.add(Container(
          padding: EdgeInsets.all(15),
          child:
              const Text('Die Speicherung dieser Einstellung ist beschädigt. '
                  'Bitte speichern sie ihre Auswahl erneut.')));
      modified.value = true;
    }

    if (storages[Storages.appSdCardDocuments] != null) {
      options.add(ListTile(
          title: const Text('SdCard Documents',
              style: TextStyle(
                backgroundColor: Colors.green,
              )),
          subtitle: Text(
            '"${storages[Storages.appSdCardDocuments]}"\n\n'
            'Externer Ordner. '
            'Versuchen Sie auf keinen Fall den Inhalt dieses Ordners zu bearbeiten solange die App Läuft.\n'
            'Sondern beenden sie zunächt das "Background Tracking", \n'
            'warten sie mindesten den eingestellten Tracking-Interval ab,\n'
            'schließen sie die App und beenden sie sie vollständig über die App Einstellungen ihres Gerätes.',
            softWrap: true,
          ),
          leading: Radio<Storages>(
              value: Storages.appSdCardDocuments,
              groupValue: selectedStorage,
              onChanged: (Storages? val) =>
                  setStorage(context, val ?? Storages.appInternal))));

      options.add(AppWidgets.divider());
    }

    ///
    if (storages[Storages.appLocalStorageDocuments] != null) {
      options.add(ListTile(
          title: const Text('Local Storage Documents',
              style: TextStyle(
                backgroundColor: Colors.green,
              )),
          subtitle: Text(
            '"Android${storages[Storages.appLocalStorageDocuments]}"\n\n'
            'Externer Ordner!\n'
            'Versuchen Sie auf keinen Fall den Inhalt dieses Ordners zu bearbeiten solange die App Läuft,\n'
            'Beenden sie zunächt das "Background Tracking", \n'
            'warten sie mindesten den eingestellten "Tracking-Interval" ab,\n'
            'schließen sie die App und beenden sie sie vollständig über die App Einstellungen ihres Gerätes.',
            softWrap: true,
          ),
          leading: Radio<Storages>(
              value: Storages.appLocalStorageDocuments,
              groupValue: selectedStorage,
              onChanged: (Storages? val) => setStorage(
                  context, val ?? Storages.appLocalStorageDocuments))));
    }

    ///
    if (storages[Storages.appLocalStorageData] != null) {
      options.add(ListTile(
          title: const Text('Local Storage Data',
              style: TextStyle(
                backgroundColor: Colors.orange,
              )),
          subtitle: Text(
            '"Android${storages[Storages.appInternal]}"\n\n'
            'Externer Ordner. Wird bei der Deinstallation gelöscht!\n'
            'Auf neuen Geräten kann dieser Ordner nur mithilfe eines Computers erreicht werden.\n'
            'Versuchen Sie auf keinen Fall den Inhalt dieses Ordners zu bearbeiten solange die App Läuft.\n'
            'Sondern beenden sie zunächt das "Background Tracking", \n'
            'warten sie mindesten den eingestellten "Tracking-Interval" ab,\n'
            'schließen sie die App und beenden sie sie vollständig über die App Einstellungen ihres Gerätes.',
            softWrap: true,
          ),
          leading: Radio<Storages>(
              value: Storages.appLocalStorageData,
              groupValue: selectedStorage,
              onChanged: (Storages? val) =>
                  setStorage(context, val ?? Storages.appInternal))));
    }

    /// Fallback folder
    options.add(AppWidgets.divider());
    options.add(ListTile(
        title: const Text('Phone Internal',
            style: TextStyle(
              backgroundColor: Colors.red,
            )),
        subtitle: Text(
          '"${storages[Storages.appInternal]}"\n\n'
          'Interner, geschützter, von außen nicht erreichbarer Ordner.\n'
          'Wird bei der deinstallation gelöscht!\n'
          'Wird beim zurücksetzen der App Daten gelöscht!\n'
          'Kann beim Update der App u.U. gelöscht werden!\n'
          'Verwenden sie dieses Verzeichnis wenn sie großen Wert auf Datenschutz legen '
          'und ihnen der erhalt der Daten nicht wichtig ist.',
          softWrap: true,
        ),
        leading: Radio<Storages>(
            value: Storages.appInternal,
            groupValue: selectedStorage,
            onChanged: (Storages? val) =>
                setStorage(context, val ?? Storages.appInternal))));

    options.add(AppWidgets.divider());
    options.add(Container(
        padding: const EdgeInsets.all(10),
        child: const Text(
            'Alle Daten werden als TSV (Tabulator-Separated-Values)'
            ' gespeichert und können leicht in eine Excel Tabelle kopiert werden.'
            ' Benutzerangaben sind systembedingt UrlCodiert, können aber z.B. über '
            'www.urldecoder.io oder mit einem Excel Add-On direkt in Excel dekodiert werden.',
            softWrap: true)));

    ///
    List<Widget> bodyStack = [
      ListView(children: [
        const ListTile(
          title: SizedBox(
              height: 40,
              child: Text('Speicherorte', style: TextStyle(fontSize: 20))),
          subtitle: Text(
              'Bitte lesen sie die Beschreibung der Speicherorte sorgfältig, '
              'bevor sie eine Entscheidung treffen!'),
        ),
        const SizedBox(height: 3),
        ...options
      ])
    ];

    ///
    if (confirmRequired) {
      bodyStack.add(Dialog(
          child: SizedBox(
              height: 190,
              child: Container(
                  padding: const EdgeInsets.all(15),
                  child: Column(children: [
                    const Text(
                      'App Neustart erforderlich',
                      softWrap: true,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Änderungen gespeichert.\nDamit sie wirksam werden '
                      'muss ChaosTours neu gestartet werden.',
                      softWrap: true,
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 20),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      TextButton(
                          child: const Text('OK'),
                          onPressed: () {
                            confirmRequired = false;
                            setState(() {});
                          }),
                    ])
                  ])))));
    }
    confirmRequired = false;

    ///
    return AppWidgets.scaffold(context,
        body: Stack(children: bodyStack),
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
                if (!corruptedSettings && !modified.value) {
                  return;
                } else {
                  Shared(SharedKeys.storageKey)
                      .saveString(selectedStorage.name)
                      .then((_) {
                    Shared(SharedKeys.storagePath)
                        .saveString(storages[selectedStorage]!);
                  }).then((_) {
                    confirmRequired = true;
                    setState(() {});
                  });
                }
                FileHandler.storageKey = selectedStorage;
                FileHandler.storagePath = storages[selectedStorage];
              } else {
                Navigator.pop(context);
              }
            }));
  }
}

class WidgetConfirm extends StatefulWidget {
  const WidgetConfirm({super.key});

  @override
  State<WidgetConfirm> createState() => _WidgetConfirm();
}

class _WidgetConfirm extends State<WidgetConfirm> {
  static final Logger logger = Logger.logger<WidgetConfirm>();

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        child: const Text('Confirm Dialog'),
        onPressed: () {
          confirm(
            context,
            title: const Text('App Neustart erforderlich'),
            content: const Text(
              'Änderungen gespeichert.\nDamit sie wirksam werden '
              'muss ChaosTours neu gestartet werden.',
              softWrap: true,
            ),
            textOK: const Text('OK'),
          ).then((bool ok) {});
        },
      ),
    );
  }
}
