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

import 'dart:io';

///
import 'package:chaostours/conf/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/view/system/app_widgets.dart';
import 'package:path/path.dart';
import 'package:chaostours/database/database.dart';
import 'package:chaostours/util.dart' as util;
import 'package:restart_app/restart_app.dart';

class WidgetImportExport extends StatefulWidget {
  const WidgetImportExport({super.key});

  @override
  State<WidgetImportExport> createState() => _WidgetImportExport();
}

class _WidgetImportExport extends State<WidgetImportExport> {
  /* @override
  Widget build(BuildContext context) {
    return AppWidgets.scaffold(context,
        body: AppWidgets.loading('Widget under construction'));
  } */

  // ignore: unused_field
  static final Logger logger = Logger.logger<WidgetImportExport>();

  bool counterIsRunning = true;
  final counter = ValueNotifier<int>(0);
  @override
  void dispose() {
    counterIsRunning = false;
    super.dispose();
  }

  @override
  void initState() {
    Future.microtask(
      () async {
        while (counterIsRunning) {
          if (counter.value > 0) {
            counter.value--;
          }
          await Future.delayed(const Duration(seconds: 1));
        }
      },
    );
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    String? databaseOpenError =
        ModalRoute.of(context)?.settings.arguments as String? ?? '';

    return Scaffold(
        appBar: AppBar(
            leading: IconButton(
                onPressed: () {},
                icon: const Icon(Icons.stop, color: Colors.transparent)),
            title: const Text('Export / Import Database')),

        ///
        ///
        /// body
        ///
        ///
        body: ListView(
          padding: const EdgeInsets.all(10),
          children: [
            ...(databaseOpenError.isEmpty
                ? []
                : [
                    ListTile(
                        title: Text(
                          'Open Database throwed Error:\n$databaseOpenError',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.copy),
                          onPressed: () {
                            Clipboard.setData(
                                ClipboardData(text: databaseOpenError));
                          },
                        ))
                  ]),

            ///
            /// export
            ///
            centerMultiline([
              '',
              'Warning!',
              'Export will stop Database and Background Tracking!',
              'In consequence you will need to restart the App to make it work again.',
              ''
            ], style: warn, color: warn.backgroundColor),
            Container(
                padding: const EdgeInsets.all(5),
                color: AppColors.black.color,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  FilledButton(
                    child: const Text('EXPORT SQLite Database'),
                    onPressed: () async {
                      _export(context);
                    },
                  )
                ])),
            Container(
                padding: const EdgeInsets.all(10), child: AppWidgets.divider()),

            ///
            /// import
            ///
            centerMultiline([
              '',
              '* * * DANGER ZONE * * *',
              'IMPORT WILL ***DELETE*** ALL DATA!',
              '!!! F O R E V E R !!!',
              'There is NO WAY to undo this action.',
              'Import will stop Database and Background Tracking!',
              'In consequence you will need to restart the App to make it work again.',
              ''
            ], style: danger, color: danger.backgroundColor),
            Container(
                padding: const EdgeInsets.all(5),
                color: AppColors.black.color,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  FilledButton(
                    child:
                        const Text('IMPORT SQLite Database and loose all Data'),
                    onPressed: () async {
                      _import(context);
                    },
                  )
                ])),
            Container(
                padding: const EdgeInsets.all(10), child: AppWidgets.divider()),

            ///
            /// reset
            ///
            centerMultiline([
              '',
              '* * * DANGER ZONE * * *',
              'RESET WILL ***DELETE*** ALL DATA!',
              '!!! F O R E V E R !!!',
              'There is NO WAY to undo this action.',
              'Reset will stop Database and Background Tracking!',
              'In consequence you will need to restart the App to make it work again.',
              ''
            ], style: danger, color: danger.backgroundColor),
            Container(
                padding: const EdgeInsets.all(5),
                color: AppColors.black.color,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  FilledButton(
                    child:
                        const Text('RESET SQLite Database and loose all Data'),
                    onPressed: () async {
                      _reset(context);
                    },
                  )
                ])),
            Container(
                padding: const EdgeInsets.all(10), child: AppWidgets.divider()),
          ],
        ));
  }

  Center center(String text, {TextStyle? style}) {
    return Center(child: Text(text, style: style));
  }

  Widget centerMultiline(List<String> lines, {Color? color, TextStyle? style}) {
    return Container(
        color: color,
        child: Column(
            children: lines.map((line) => Text(line, style: style)).toList()));
  }

  final danger = TextStyle(
      color: AppColors.black.color,
      backgroundColor: AppColors.danger.color,
      fontWeight: FontWeight.bold);
  final warn = TextStyle(
      color: AppColors.black.color,
      backgroundColor: AppColors.warning.color,
      fontWeight: FontWeight.bold);

  Future<void> dialogActionLog(
      BuildContext context, String title, Stream<Widget> stream) async {
    final notifier = ValueNotifier<Widget>(const SizedBox.shrink());
    final List<Widget> log = [];
    AppWidgets.dialog(
        context: context,
        isDismissible: false,
        title: Text(title),
        contents: [
          ValueListenableBuilder(
            valueListenable: notifier,
            builder: (context, widget, child) {
              log.add(widget);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: log,
              );
            },
          )
        ],
        buttons: []);
    Future.delayed(const Duration(milliseconds: 300), () async {
      await for (var msg in stream) {
        notifier.value = msg;
      }
    });
  }

  Future<void> dialogShutdown(BuildContext context) async {
    AppWidgets.dialog(
        context: context,
        isDismissible: false,
        buttons: [],
        contents: [const Text('Restart Chaostours...')]);
    Future.delayed(const Duration(milliseconds: 1500), () async {
      Restart.restartApp();
    });
  }

  final textInputNotifier = ValueNotifier<String>('');
  final textFilenameController = TextEditingController();
  final textImportCodeController = TextEditingController();
  final textResetCodeController = TextEditingController();
  final maxChars = 80;

  final submitNotifier = ValueNotifier<bool>(true);

  final prefix = 'chaostours_database_v${DB.dbVersion}';
  String get suffix => '${util.formatDateFilename(DateTime.now())}.sqlite';

  Future<void> _export(BuildContext context) async {
    String? path = await FilePicker.platform.getDirectoryPath();

    if (!mounted || path == null || path == '/') {
      return;
    }
    textFilenameController.text = '';
    textInputNotifier.value = '';

    final regex = RegExp(r'[A-Za-z0-9_]*');
    String? validateFilename(String? value) {
      if (value == null || value.isEmpty) {
        return null;
      }
      if (value.length > maxChars) {
        return 'Filename is too long';
      }
      String match = regex.allMatches(value).first.group(0) ?? '';
      if (match != value) {
        return 'Filename contains restricted chars';
      }
      return null;
    }

    String generateFilename(String value) {
      bool isValid = validateFilename(value) == null;
      value = isValid ? '_${value.toLowerCase()}_' : '_';
      return '$prefix${value.isEmpty ? '_' : value}$suffix';
    }

    await AppWidgets.dialog(
      context: context,
      title: const Text('Export Database'),
      contents: [
        const Text('Enter optional filename with [A-Za-z0-9_]'),
        TextFormField(
          autovalidateMode: AutovalidateMode.always,
          autofocus: true,
          controller: textFilenameController,
          onChanged: (value) {
            textInputNotifier.value = value;
          },
          validator: validateFilename,
        ),
        ValueListenableBuilder(
          valueListenable: textInputNotifier,
          builder: (context, value, child) {
            String filename = generateFilename(value);
            String fullPath = join(path, filename);

            File file = File(fullPath);
            bool fileExists = file.existsSync();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: Text(
                      (maxChars - textInputNotifier.value.length).toString()),
                ),
                Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Center(
                        child: FilledButton(
                      onPressed: validateFilename(value) == null && !fileExists
                          ? () {
                              dialogActionLog(
                                  context,
                                  'Export to:\n$filename',
                                  DB.exportDatabase(fullPath,
                                      onSuccess: () => dialogShutdown(context),
                                      onError: () => Future.delayed(
                                          const Duration(seconds: 2),
                                          () => Navigator.pop(context))));
                            }
                          : null,
                      child:
                          Text(fileExists ? 'File already exists' : 'Export'),
                    ))),
                Text('Full path will be:\n$fullPath'),
              ],
            );
          },
        )
      ],
      buttons: [],
    );
  }

  final int randomLength = 10;
  Future<void> _import(BuildContext context) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (!mounted || result == null || result.count == 0) {
      return;
    }
    String path = result.files.firstOrNull?.path ?? '';
    if (path == '/') {
      return;
    }

    textFilenameController.text = '';
    textInputNotifier.value = '';
    String code = util.getRandomString(randomLength);

    String? validateCode(String? value) {
      if (value == null || value.isEmpty) {
        return null;
      }
      return value == code ? null : 'Incorrect Code';
    }

    AppWidgets.dialog(
        context: context,
        title: const Text('Import Database'),
        contents: [
          ValueListenableBuilder(
            valueListenable: counter,
            builder: (context, value, child) {
              var text = Text('Please Type this code: $code');
              if (value == 1) {
                code = util.getRandomString(randomLength);
              }
              return text;
            },
          ),
          TextFormField(
            autovalidateMode: AutovalidateMode.always,
            //key: _formKey,
            autofocus: true,
            controller: textImportCodeController,
            onChanged: (value) {
              counter.value = randomLength * 2;
              textInputNotifier.value = value;
            },
            validator: validateCode,
          ),
        ],
        buttons: [
          ValueListenableBuilder(
              valueListenable: counter,
              builder: (context, value, child) {
                bool isValid =
                    validateCode(textImportCodeController.text) == null &&
                        counter.value > 0;
                return Column(
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: Text(counter.value == 0
                          ? ''
                          : 'Edit Countdown: ${counter.value.toString()}'),
                    ),
                    Column(children: [
                      isValid
                          ? Container(
                              color: AppColors.danger.color,
                              padding: const EdgeInsets.all(3),
                              child: Text(
                                'Last WARNING! You WILL loose all data forever!',
                                style: danger,
                              ))
                          : const SizedBox.shrink(),
                      Center(
                          child: FilledButton(
                        onPressed: isValid
                            ? () {
                                dialogActionLog(
                                    context,
                                    'Import Database',
                                    DB.importDatabase(path,
                                        onSuccess: () =>
                                            dialogShutdown(context),
                                        onError: () => Future.delayed(
                                            const Duration(seconds: 2),
                                            () => Navigator.pop(context))));
                              }
                            : null,
                        child: const Text('Import Database'),
                      ))
                    ])
                  ],
                );
              })
        ]);
  }

  Future<void> _reset(BuildContext context) async {
    textInputNotifier.value = '';
    String code = util.getRandomString(randomLength);

    String? validateCode(String? value) {
      if (value == null || value.isEmpty) {
        return null;
      }
      return value == code ? null : 'Incorrect Code';
    }

    AppWidgets.dialog(
        context: context,
        title: const Text('Reset Database'),
        contents: [
          ValueListenableBuilder(
            valueListenable: counter,
            builder: (context, value, child) {
              var text = Text('Please Type this code: $code');
              if (value == 1) {
                code = util.getRandomString(randomLength);
              }
              return text;
            },
          ),
          TextFormField(
            autovalidateMode: AutovalidateMode.always,
            //key: _formKey,
            autofocus: true,
            controller: textImportCodeController,
            onChanged: (value) {
              counter.value = randomLength * 2;
              textInputNotifier.value = value;
            },
            validator: validateCode,
          ),
        ],
        buttons: [
          ValueListenableBuilder(
              valueListenable: counter,
              builder: (context, value, child) {
                bool isValid =
                    validateCode(textImportCodeController.text) == null &&
                        counter.value > 0;
                return Column(
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: Text(counter.value == 0
                          ? ''
                          : 'Edit Countdown: ${counter.value.toString()}'),
                    ),
                    Column(children: [
                      isValid
                          ? Container(
                              color: AppColors.danger.color,
                              padding: const EdgeInsets.all(3),
                              child: Text(
                                'Last WARNING! You WILL loose all data forever!',
                                style: danger,
                              ))
                          : const SizedBox.shrink(),
                      Center(
                          child: FilledButton(
                        onPressed: isValid
                            ? () async {
                                dialogActionLog(
                                    context,
                                    'Reset Database',
                                    DB.deleteDatabase(
                                        onSuccess: () =>
                                            dialogShutdown(context),
                                        onError: () => Future.delayed(
                                            const Duration(seconds: 2),
                                            () => Navigator.pop(context))));
                              }
                            : null,
                        child: const Text('Reset Database'),
                      ))
                    ])
                  ],
                );
              })
        ]);
  }
}
