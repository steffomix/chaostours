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
import 'package:file_manager/file_manager.dart';
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

  ValueNotifier<bool> isBaseDir = ValueNotifier(true);
  ValueNotifier<bool> hasImportFiles = ValueNotifier(false);
  String trackPointFilename = 'trackpoint';
  String userFilename = 'user';
  String taskFilename = 'task';
  String aliasFilename = 'alias';

  FileManagerController fileManagerController = FileManagerController();
  @override
  Widget build(BuildContext context) {
    FloatingActionButton? floatingActionButton;
    Permission.manageExternalStorage.isGranted.then((bool granted) {
      if (!granted) {
        floatingActionButton = FloatingActionButton.extended(
            onPressed: () async {
              AppWidgets.navigate(context, AppRoutes.permissions);
            },
            label: const Text("Check File Permission"));
        setState(() {});
      }
    });

    return ControlBackButton(
      controller: fileManagerController,
      child: Scaffold(
          bottomNavigationBar: BottomNavigationBar(
              currentIndex: 1,
              type: BottomNavigationBarType.fixed,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.file_download),
                  label: 'Export',
                ),
                BottomNavigationBarItem(
                    icon: Icon(Icons.cancel), label: 'Cancel'),
                BottomNavigationBarItem(
                  icon: Icon(Icons.file_upload),
                  label: 'Import',
                ),
              ],
              onTap: (int id) async {
                /// export here
                var dir = fileManagerController.getCurrentDirectory;

                /// export database
                if (id == 0) {
                  final notifier =
                      ValueNotifier<Widget>(const SizedBox.shrink());
                  final List<Widget> log = [];
                  AppWidgets.dialog(
                      context: context,
                      isDismissible: false,
                      title: const Text('Export Database'),
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
                  await for (var msg in DB.exportDatabase(context, dir)) {
                    notifier.value = msg;
                  }
                }

                /// import database
                if (id == 2) {
                  var result = await FilePicker.platform.getDirectoryPath();

                  /* await for (Widget msg in DB.exportDatabase(context, dir)) {
                    print('### $msg');
                  } */
                  Fluttertoast.showToast(msg: 'Database exported');
                }

                /// return
                if (id == 1) {
                  if (mounted) {
                    AppWidgets.navigate(context, AppRoutes.liveTracking);
                  }
                }
              }),
          appBar: appBar(context),
          body: FileManager(
            controller: fileManagerController,
            builder: (context, snapshot) {
              fileManagerController
                  .isRootDirectory()
                  .then((value) => isBaseDir.value = value);
              Future.microtask(() async {
                try {
                  var isRoot = await fileManagerController.isRootDirectory();

                  var path = fileManagerController.getCurrentPath;
                  bool tp =
                      File(join(path, '$trackPointFilename.tsv')).existsSync();
                  bool usr = File(join(path, '$userFilename.tsv')).existsSync();
                  bool tsk = File(join(path, '$taskFilename.tsv')).existsSync();
                  bool als =
                      File(join(path, '$aliasFilename.tsv')).existsSync();
                  if (mounted) {
                    hasImportFiles.value = (tp || usr || tsk || als);
                    isBaseDir.value = isRoot;
                  }
                } catch (e, stk) {
                  logger.error(e, stk);
                }
              });

              final List<FileSystemEntity> entities = snapshot;
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
                itemCount: entities.length,
                itemBuilder: (context, index) {
                  FileSystemEntity entity = entities[index];
                  return Card(
                    child: ListTile(
                      leading: FileManager.isFile(entity)
                          ? const Icon(Icons.feed_outlined)
                          : const Icon(Icons.folder),
                      title: Text(FileManager.basename(
                        entity,
                        showFileExtension: true,
                      )),
                      subtitle: subtitle(entity),
                      onTap: () async {
                        if (FileManager.isDirectory(entity)) {
                          fileManagerController.openDirectory(entity);
                        }
                      },
                    ),
                  );
                },
              );
            },
          ),
          floatingActionButton: floatingActionButton),
    );
  }

  AppBar appBar(BuildContext context) {
    return AppBar(
      actions: [
        IconButton(
          onPressed: () {
            AppWidgets.navigate(context, AppRoutes.liveTracking);
          },
          icon: const Icon(Icons.navigation),
        ),
        IconButton(
          onPressed: () {
            AppWidgets.navigate(context, AppRoutes.importExport);
          },
          icon: const Icon(Icons.home),
        ),
        IconButton(
          onPressed: () => createFolder(context),
          icon: const Icon(Icons.create_new_folder_outlined),
        ),
        IconButton(
          onPressed: () => sort(context),
          icon: const Icon(Icons.sort_rounded),
        ),
        IconButton(
          onPressed: () => selectStorage(context),
          icon: const Icon(Icons.sd_storage_rounded),
        )
      ],
      title: ValueListenableBuilder<String>(
        valueListenable: fileManagerController.titleNotifier,
        builder: (context, title, _) => Text(title),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () async {
          fileManagerController.isRootDirectory().then((bool isRoot) async {
            if (isRoot) {
              AppWidgets.navigate(context, AppRoutes.liveTracking);
            } else {
              await fileManagerController.goToParentDirectory();
            }
          });
        },
      ),
    );
  }

  Widget subtitle(FileSystemEntity entity) {
    return FutureBuilder<FileStat>(
      future: entity.stat(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          if (entity is File) {
            int size = snapshot.data!.size;

            return Text(
              FileManager.formatBytes(size),
            );
          }
          return Text(
            "${snapshot.data!.modified}".substring(0, 10),
          );
        } else {
          return const Text("");
        }
      },
    );
  }

  Future<List<Directory>> dbPath() async {
    return Future.delayed(
        const Duration(milliseconds: 10),
        () async => <Directory>[
              //Directory('/data/user/0/com.stefanbrinkmann.chaosToursUnlimited'),
              ...await FileManager.getStorageList()
            ]);
  }

  Future<void> selectStorage(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (context) => Dialog(
        child: FutureBuilder<List<Directory>>(
          future: dbPath(), //FileManager.getStorageList(),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              final List<FileSystemEntity> storageList = snapshot.data!;
              return Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: storageList
                        .map((e) => ListTile(
                              title: Text(
                                FileManager.basename(e),
                              ),
                              onTap: () {
                                fileManagerController.openDirectory(Directory(
                                    '/data/user/0/com.stefanbrinkmann.chaosToursUnlimited'));
                                Navigator.pop(context);
                              },
                            ))
                        .toList()),
              );
            }

            return Container(
                height: 200,
                padding: const EdgeInsets.all(10.0),
                child: AppWidgets.loading(const Text('Waiting for Data')));
          },
        ),
      ),
    );
  }

  sort(BuildContext context) async {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                  title: const Text("Name"),
                  onTap: () {
                    fileManagerController.sortBy(SortBy.name);
                    Navigator.pop(context);
                  }),
              ListTile(
                  title: const Text("Size"),
                  onTap: () {
                    fileManagerController.sortBy(SortBy.size);
                    Navigator.pop(context);
                  }),
              ListTile(
                  title: const Text("Date"),
                  onTap: () {
                    fileManagerController.sortBy(SortBy.date);
                    Navigator.pop(context);
                  }),
              ListTile(
                  title: const Text("type"),
                  onTap: () {
                    fileManagerController.sortBy(SortBy.type);
                    Navigator.pop(context);
                  }),
            ],
          ),
        ),
      ),
    );
  }

  createFolder(BuildContext context) async {
    showDialog(
      context: context,
      builder: (context2) {
        TextEditingController folderName = TextEditingController();
        return Dialog(
          child: Container(
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: TextField(
                    controller: folderName,
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      // Create Folder
                      await FileManager.createFolder(
                          fileManagerController.getCurrentPath,
                          folderName.text);
                      // Open Created Folder
                      fileManagerController.setCurrentPath = join(
                          fileManagerController.getCurrentPath,
                          folderName.text);
                    } catch (e) {
                      // ignore
                    }
                    if (mounted) {
                      Navigator.pop(context2);
                    }
                  },
                  child: const Text('Create Folder'),
                )
              ],
            ),
          ),
        );
      },
    );
  }
}
