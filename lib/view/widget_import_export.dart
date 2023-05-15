import 'package:flutter/material.dart';
import 'package:file_manager/file_manager.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

///
import 'package:chaostours/model/model_alias.dart';
import 'package:chaostours/model/model_task.dart';
import 'package:chaostours/model/model_trackpoint.dart';
import 'package:chaostours/model/model_user.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/view/app_widgets.dart';
import 'package:path/path.dart';
import 'package:chaostours/cache.dart';

class WidgetImportExport extends StatefulWidget {
  const WidgetImportExport({super.key});

  @override
  State<WidgetImportExport> createState() => _WidgetImportExport();
}

class _WidgetImportExport extends State<WidgetImportExport> {
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

  Future<Map<String, bool>> getFiles(FileManagerController controller) async {
    Map<String, bool> files = {};
    try {
      var isRoot = await controller.isRootDirectory();

      var path = controller.getCurrentPath;
      bool tp = File(join(path, '$trackPointFilename.tsv')).existsSync();
      bool usr = File(join(path, '$userFilename.tsv')).existsSync();
      bool tsk = File(join(path, '$taskFilename.tsv')).existsSync();
      bool als = File(join(path, '$aliasFilename.tsv')).existsSync();
      if (mounted) {
        hasImportFiles.value = (tp || usr || tsk || als);
        isBaseDir.value = isRoot;
      }
      return <String, bool>{
        trackPointFilename: tp,
        userFilename: usr,
        taskFilename: tsk,
        aliasFilename: als,
        'error': false
      };
    } catch (e, stk) {
      logger.error(e, stk);
      return <String, bool>{
        trackPointFilename: false,
        userFilename: false,
        taskFilename: false,
        aliasFilename: false,
        'error': true
      };
    }
  }

  Future<void> exportDatabaseFiles(
      FileManagerController controller, Directory dir) async {
    /// export trackPoints
    String path, tsv;
    File f;
    List<ModelTrackPoint> tpList = await Cache.getValue<List<ModelTrackPoint>>(
        CacheKeys.tableModelTrackpoint, []);
    path = join(dir.path, '$trackPointFilename.tsv');
    tsv = tpList
        .map(
          (e) => e.toString(),
        )
        .join('\n');
    f = File(path);
    await f.writeAsString(tsv);

    /// export alias
    List<ModelAlias> aliasList =
        await Cache.getValue<List<ModelAlias>>(CacheKeys.tableModelAlias, []);
    path = join(dir.path, '$aliasFilename.tsv');
    tsv = aliasList
        .map(
          (e) => e.toString(),
        )
        .join('\n');
    f = File(path);
    await f.writeAsString(tsv);

    /// export tasks
    List<ModelTask> taskList =
        await Cache.getValue<List<ModelTask>>(CacheKeys.tableModelTask, []);
    path = join(dir.path, '$taskFilename.tsv');
    tsv = taskList
        .map(
          (e) => e.toString(),
        )
        .join('\n');
    f = File(path);
    await f.writeAsString(tsv);

    /// export users
    List<ModelUser> userList =
        await Cache.getValue<List<ModelUser>>(CacheKeys.tableModelUser, []);
    path = join(dir.path, '$userFilename.tsv');
    tsv = userList
        .map(
          (e) => e.toString(),
        )
        .join('\n');
    f = File(path);
    await f.writeAsString(tsv);

    Fluttertoast.showToast(msg: 'Files Exported');
  }

  Future<void> importDatabaseFiles(BuildContext context, String dir) async {
    List<String> errors = [];
    List<ModelTrackPoint> trackPointModels = [];
    List<ModelAlias> aliasModels = [];
    List<ModelTask> taskModels = [];
    List<ModelUser> userModels = [];

    await Cache.reload();

    /// trackpoint.tsv
    /// check ids
    try {
      var file = trackPointFilename;
      File f = File(join(dir, '$file.tsv'));
      if (f.existsSync()) {
        List<String> data = f.readAsStringSync().split('\n');
        var id = 1;
        for (var row in data) {
          try {
            ModelTrackPoint model = ModelTrackPoint.toModel(row);
            if (model.id != id) {
              throw ('id must be $id');
            }
            trackPointModels.add(model);
          } catch (e) {
            throw ('$file.tsv line ${id - 1}: $e');
          }
          id++;
        }
      } else {
        trackPointModels = await Cache.getValue<List<ModelTrackPoint>>(
            CacheKeys.tableModelTrackpoint, []);
      }
    } catch (e) {
      errors.add(e.toString());
    }

    /// alias.tsv
    /// ceck id
    try {
      var file = aliasFilename;
      File f = File(join(dir, '$file.tsv'));
      if (await f.exists()) {
        List<String> data = f.readAsStringSync().split('\n');
        var id = 1;
        for (var row in data) {
          try {
            ModelAlias model = ModelAlias.toModel(row);
            if (model.id != id) {
              throw ('id must be $id');
            }
            aliasModels.add(model);
          } catch (e) {
            throw ('$file.tsv line ${id - 1}: $e');
          }
          id++;
        }
      } else {
        aliasModels = await Cache.getValue<List<ModelAlias>>(
            CacheKeys.tableModelAlias, []);
      }
    } catch (e) {
      errors.add(e.toString());
    }

    /// task.tsv
    /// ceck id
    try {
      var file = taskFilename;
      File f = File(join(dir, '$file.tsv'));
      if (await f.exists()) {
        List<String> data = f.readAsStringSync().split('\n');
        var id = 1;
        for (var row in data) {
          try {
            ModelTask model = ModelTask.toModel(row);
            if (model.id != id) {
              throw ('id must be $id');
            }
            taskModels.add(model);
          } catch (e) {
            throw ('$file.tsv line ${id - 1}: $e');
          }
          id++;
        }
      } else {
        taskModels =
            await Cache.getValue<List<ModelTask>>(CacheKeys.tableModelTask, []);
      }
    } catch (e) {
      errors.add(e.toString());
    }

    /// user.tsv
    /// ceck id
    try {
      var file = userFilename;
      File f = File(join(dir, '$file.tsv'));
      if (await f.exists()) {
        List<String> data = f.readAsStringSync().split('\n');
        var id = 1;
        for (var row in data) {
          try {
            ModelUser model = ModelUser.toModel(row);
            if (model.id != id) {
              throw ('id must be $id');
            }
            userModels.add(model);
          } catch (e) {
            throw ('$file.tsv line ${id - 1}: $e');
          }
          id++;
        }
      } else {
        userModels = await Cache.getValue(CacheKeys.tableModelUser, []);
      }
    } catch (e) {
      errors.add(e.toString());
    }

    /// check relational integrity
    if (errors.isEmpty) {
      try {
        int line = 0;
        for (var tp in trackPointModels) {
          for (var id in tp.idAlias) {
            if (id < 1 || id > aliasModels.length) {
              throw ('$trackPointFilename.tsv line $line: alias id must be > 0 and < ${aliasModels.length + 1}');
            }
          }
          for (var id in tp.idTask) {
            if (id < 1 || id > taskModels.length) {
              throw ('$trackPointFilename.tsv line $line: task id must be > 0 and < ${taskModels.length + 1}');
            }
          }
          for (var id in tp.idUser) {
            if (id < 1 || id > userModels.length) {
              throw ('$trackPointFilename.tsv line $line: user id must be > 0 and < ${userModels.length + 1}');
            }
          }
          line++;
        }
      } catch (e) {
        errors.add(e.toString());
      }
    }
    if (errors.isEmpty) {
      await Cache.setValue<List<ModelTrackPoint>>(
          CacheKeys.tableModelTrackpoint, trackPointModels);
      await Cache.setValue<List<ModelAlias>>(
          CacheKeys.tableModelAlias, aliasModels);
      await Cache.setValue<List<ModelTask>>(
          CacheKeys.tableModelTask, taskModels);
      await Cache.setValue<List<ModelUser>>(
          CacheKeys.tableModelUser, userModels);
      await Cache.reload();
      await ModelTrackPoint.open();
      await ModelTrackPoint.resetIds();
      await ModelAlias.open();
      await ModelTask.open();
      await ModelUser.open();
      Fluttertoast.showToast(msg: 'Data imported');
    } else {
      Fluttertoast.showToast(msg: 'Import error(s)');
      Future.microtask(() {
        AppWidgets.navigate(context, AppRoutes.logger).then((_) async {
          for (var e in errors) {
            await Future.delayed(const Duration(milliseconds: 200));
            logger.error('Import Error: $e', StackTrace.empty);
          }
        });
      });
    }
  }

  FileManagerController controller = FileManagerController();
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
      controller: controller,
      child: Scaffold(
          bottomNavigationBar: BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              fixedColor: AppColors.black.color,
              backgroundColor: AppColors.yellow.color,
              items: [
                BottomNavigationBarItem(
                  icon: ValueListenableBuilder<bool>(
                    valueListenable: isBaseDir,
                    builder: (context, value, child) {
                      if (value) {
                        return const Icon(Icons.file_download_off);
                      } else {
                        return const Icon(Icons.file_download);
                      }
                    },
                  ),
                  label: 'Export',
                ),
                const BottomNavigationBarItem(
                    icon: Icon(Icons.cancel), label: 'Cancel'),
                BottomNavigationBarItem(
                  icon: ValueListenableBuilder<bool>(
                    valueListenable: hasImportFiles,
                    builder: (context, value, child) {
                      if (value) {
                        return const Icon(Icons.file_upload);
                      } else {
                        return const Icon(Icons.file_upload_off);
                      }
                    },
                  ),
                  label: 'Import',
                ),
              ],
              onTap: (int id) async {
                /// export here
                var dir = controller.getCurrentDirectory;
                var path = controller.getCurrentPath;
                var strike =
                    const TextStyle(decoration: TextDecoration.lineThrough);

                /// export database
                if (id == 0) {
                  if (!isBaseDir.value) {
                    Map<String, bool> files = await getFiles(controller);
                    if (mounted) {
                      showDialog(
                          context: context,
                          builder: (context) {
                            return Dialog(
                                child: Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                            'Export Database Files into "$path"?'),
                                        files[trackPointFilename] ?? false
                                            ? Text(
                                                '- $trackPointFilename.tsv',
                                                style: strike,
                                              )
                                            : Text('- $trackPointFilename.tsv'),
                                        files[aliasFilename] ?? false
                                            ? Text(
                                                '- $aliasFilename.tsv',
                                                style: strike,
                                              )
                                            : Text('- $aliasFilename.tsv'),
                                        files[taskFilename] ?? false
                                            ? Text(
                                                '- $taskFilename.tsv',
                                                style: strike,
                                              )
                                            : Text('- $taskFilename.tsv'),
                                        files[userFilename] ?? false
                                            ? Text(
                                                '- $userFilename.tsv',
                                                style: strike,
                                              )
                                            : Text('- $trackPointFilename.tsv'),
                                        AppWidgets.divider(),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            TextButton(
                                              child: const Text('Yes'),
                                              onPressed: () async {
                                                /// export
                                                logger.log('export');
                                                Navigator.pop(context);
                                                await exportDatabaseFiles(
                                                    controller, dir);
                                                controller
                                                    .goToParentDirectory()
                                                    .then((_) {
                                                  controller.openDirectory(dir);
                                                });
                                              },
                                            ),
                                            TextButton(
                                              style: const ButtonStyle(
                                                  alignment:
                                                      Alignment.centerRight),
                                              child: const Text('Hell, NO!'),
                                              onPressed: () {
                                                Navigator.pop(context);
                                              },
                                            )
                                          ],
                                        )
                                      ],
                                    )));
                          });
                    }
                  }
                }

                /// import database
                if (id == 2) {
                  if (hasImportFiles.value) {
                    Map<String, bool> files = await getFiles(controller);
                    if (mounted) {
                      showDialog(
                          context: context,
                          builder: (context) {
                            return Dialog(
                                child: Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                            'Import Database Files from "$path"?'),
                                        files[trackPointFilename] ?? false
                                            ? Text('- $trackPointFilename.tsv')
                                            : Text(
                                                '- $trackPointFilename.tsv',
                                                style: strike,
                                              ),
                                        files[aliasFilename] ?? false
                                            ? Text('- $aliasFilename.tsv')
                                            : Text(
                                                '- $aliasFilename.tsv',
                                                style: strike,
                                              ),
                                        files[taskFilename] ?? false
                                            ? Text('- $taskFilename.tsv')
                                            : Text(
                                                '- $taskFilename.tsv',
                                                style: strike,
                                              ),
                                        files[userFilename] ?? false
                                            ? Text('- $userFilename.tsv')
                                            : Text(
                                                '- $trackPointFilename.tsv',
                                                style: strike,
                                              ),
                                        AppWidgets.divider(),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            TextButton(
                                              child: const Text('Yes, DO IT!'),
                                              onPressed: () async {
                                                /// export
                                                logger.log('export');
                                                Navigator.pop(context);
                                                await importDatabaseFiles(
                                                    context, path);
                                              },
                                            ),
                                            TextButton(
                                              style: const ButtonStyle(
                                                  alignment:
                                                      Alignment.centerRight),
                                              child: const Text('Hell, NO!'),
                                              onPressed: () {
                                                Navigator.pop(context);
                                              },
                                            )
                                          ],
                                        )
                                      ],
                                    )));
                          });
                    }
                  }
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
            controller: controller,
            builder: (context, snapshot) {
              controller
                  .isRootDirectory()
                  .then((value) => isBaseDir.value = value);
              Future.microtask(() async {
                try {
                  var isRoot = await controller.isRootDirectory();

                  var path = controller.getCurrentPath;
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
                          controller.openDirectory(entity);
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
        valueListenable: controller.titleNotifier,
        builder: (context, title, _) => Text(title),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () async {
          controller.isRootDirectory().then((bool isRoot) async {
            if (isRoot) {
              AppWidgets.navigate(context, AppRoutes.liveTracking);
            } else {
              await controller.goToParentDirectory();
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

  Future<void> selectStorage(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (context) => Dialog(
        child: FutureBuilder<List<Directory>>(
          future: FileManager.getStorageList(),
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
                                controller.openDirectory(e);
                                Navigator.pop(context);
                              },
                            ))
                        .toList()),
              );
            }

            return Container(
                height: 200,
                padding: const EdgeInsets.all(10.0),
                child: AppWidgets.loading('Waiting for Data'));
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
                    controller.sortBy(SortBy.name);
                    Navigator.pop(context);
                  }),
              ListTile(
                  title: const Text("Size"),
                  onTap: () {
                    controller.sortBy(SortBy.size);
                    Navigator.pop(context);
                  }),
              ListTile(
                  title: const Text("Date"),
                  onTap: () {
                    controller.sortBy(SortBy.date);
                    Navigator.pop(context);
                  }),
              ListTile(
                  title: const Text("type"),
                  onTap: () {
                    controller.sortBy(SortBy.type);
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
                          controller.getCurrentPath, folderName.text);
                      // Open Created Folder
                      controller.setCurrentPath =
                          join(controller.getCurrentPath, folderName.text);
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
