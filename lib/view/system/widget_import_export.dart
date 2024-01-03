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

import 'package:chaostours/conf/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:file_manager/file_manager.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

///
import 'package:chaostours/conf/app_routes.dart';
/*
import 'package:chaostours/model/model.dart';
import 'package:chaostours/model/model_alias.dart';
import 'package:chaostours/model/model_task.dart';
import 'package:chaostours/model/model_trackpoint.dart';
import 'package:chaostours/model/model_user.dart';
import 'package:chaostours/cache.dart';
*/
import 'package:chaostours/logger.dart';
import 'package:chaostours/view/app_widgets.dart';
import 'package:path/path.dart';
import 'package:chaostours/database/database.dart';
import 'package:chaostours/util.dart' as util;

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

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
  }

  FileManagerController fileManagerController = FileManagerController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
            leading: IconButton(onPressed: () {}, icon: Icon(Icons.stop)),
            title: const Text('Export / Import Database')),

        ///
        ///
        /// body
        ///
        ///
        body: ListView(
          padding: const EdgeInsets.all(10),
          children: [
            ///
            /// export
            ///
            centerMultiline([
              '',
              'Warning!',
              'Export will stop Database and Background Tracking!',
              'In consequence you will need to restart the App to make it work again.',
              ''
            ], style: danger, color: danger.backgroundColor),
            Container(
                padding: const EdgeInsets.all(5),
                color: AppColors.black.color,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  ElevatedButton(
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
              'There is NO WAY to undo this action',
              'Import will stop Database and Background Tracking!',
              'In consequence you will need to restart the App to make it work again.',
              ''
            ], style: danger, color: danger.backgroundColor),
            Container(
                padding: const EdgeInsets.all(5),
                color: AppColors.black.color,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  ElevatedButton(
                    child: const Text('IMPORT SQLite Database'),
                    onPressed: () async {
                      _export(context);
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
              'There is NO WAY to undo this action',
              'Reset will stop Database and Background Tracking!',
              'In consequence you will need to restart the App to make it work again.',
              ''
            ], style: danger, color: danger.backgroundColor),
            Container(
                padding: const EdgeInsets.all(5),
                color: AppColors.black.color,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  ElevatedButton(
                    child: const Text('DELETE AND RESET SQLite Database'),
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
      color: AppColors.danger.color,
      backgroundColor: Colors.black,
      fontWeight: FontWeight.bold);
  final warn = TextStyle(
      color: AppColors.warning.color,
      backgroundColor: Colors.black,
      fontWeight: FontWeight.bold);

  Future<void> dialogActionLog(BuildContext context, String title,
      Stream<Widget> Function() action) async {
    final notifier = ValueNotifier<Widget>(const SizedBox.shrink());
    final List<Widget> log = [];
    await AppWidgets.dialog(
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
    await for (var msg in action.call()) {
      notifier.value = msg;
    }
  }

  final _formKey = GlobalKey<FormState>();
  Future<void> dialogShutdown(BuildContext context) async {
    AppWidgets.dialog(
        context: context,
        isDismissible: false,
        buttons: [],
        contents: [const Text('Shutting down Chaostours...')]);
    Future.delayed(const Duration(milliseconds: 1500), () {
      SystemNavigator.pop();
    });
  }

  final filenameNotifier = ValueNotifier<String>('');
  final textController = TextEditingController();
  final maxChars = 80;

  final submitNotifier = ValueNotifier<bool>(true);

  Future<void> _export(BuildContext context) async {
    String? path = await FilePicker.platform.getDirectoryPath();

    if (!mounted || path == null || path == '/') {
      return;
    }

    const prefix = 'chaostours_${DB.dbFile}';
    final suffix = '${util.formatDateFilename(DateTime.now())}.dart';

    final regex = RegExp(r'[A-Za-z0-9_]*');
    String? validateFilename(String? value) {
      if (value == null || value.isEmpty) {
        return null;
      }
      if (value.length > 100) {
        return 'Filename is too long';
      }
      String match = regex.allMatches(value).first.group(0) ?? '';
      if (match != value) {
        return 'Filename contains restricted chars';
      }
      return null;
    }

    String generateFullPath(String value) {
      bool isValid = validateFilename(value) == null;
      value = isValid ? '_${value.toLowerCase()}_' : '_';
      String filename = '$prefix${value.isEmpty ? '_' : value}$suffix';
      return join(path, filename);
    }

    await AppWidgets.dialog(
      context: context,
      title: const Text('Export Database'),
      contents: [
        const Text('Please enter filename with [A-Za-z0-9_]'),
        TextFormField(
          autovalidateMode: AutovalidateMode.always,
          //key: _formKey,
          autofocus: true,
          controller: textController,
          onChanged: (value) {
            filenameNotifier.value = value;
          },
          validator: validateFilename,
        ),
        ValueListenableBuilder(
          valueListenable: filenameNotifier,
          builder: (context, value, child) {
            String fullPath = generateFullPath(value);

            File file = File(fullPath);
            bool fileExists = file.existsSync();

            TextStyle? style = fileExists
                ? null
                : const TextStyle(
                    color: Colors.red, backgroundColor: Colors.black);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: Text(
                      (maxChars - filenameNotifier.value.length).toString()),
                ),
                Text('Full path will be:\n$fullPath'),
                Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Center(
                        child: ElevatedButton(
                      child: Text('Export'),
                      onPressed: validateFilename(value) == null
                          ? () {
                              DB.exportDatabase(context, fullPath);
                            }
                          : null,
                    )))
              ],
            );
          },
        )
      ],
      buttons: [],
    );
  }

  Future<void> _import(BuildContext context) async {
    String? path = await FilePicker.platform.getDirectoryPath();
  }

  Future<void> _reset(BuildContext context) async {
    String? path = await FilePicker.platform.getDirectoryPath();
  }
}
