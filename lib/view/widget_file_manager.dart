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

class WidgetStorageSettings extends StatefulWidget {
  const WidgetStorageSettings({super.key});

  @override
  State<WidgetStorageSettings> createState() => _WidgetStorageSettings();
}

class _WidgetStorageSettings extends State<WidgetStorageSettings> {
  // ignore: unused_field
  static final Logger logger = Logger.logger<WidgetStorageSettings>();

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
  }

  ValueNotifier<bool> isBaseDir = ValueNotifier(true);

  Future<void> exportDatabaseFiles(Directory dir) async {
    /// export trackPoints
    String path, tsv;
    File f;
    List<ModelTrackPoint> tpList = await Cache.getValue<List<ModelTrackPoint>>(
        CacheKeys.tableModelTrackpoint, []);
    path = join(dir.path, 'trackpoint.tsv');
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
    path = join(dir.path, 'alias.tsv');
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
    path = join(dir.path, 'task.tsv');
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
    path = join(dir.path, 'user.tsv');
    tsv = userList
        .map(
          (e) => e.toString(),
        )
        .join('\n');
    f = File(path);
    await f.writeAsString(tsv);

    Fluttertoast.showToast(msg: 'Files Exported');
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
                const BottomNavigationBarItem(
                    icon: Icon(Icons.upload), label: 'Import')
              ],
              onTap: (int id) async {
                /// export here
                if (id == 0) {
                  // export

                  var dir = controller.getCurrentDirectory;
                  var path = controller.getCurrentPath;
                  if (!(await controller.isRootDirectory())) {
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
                                            'Export Database Files\n- trackpoint.tsv\n- alias.tsv\n- task.tsv\n- user.tsv\ninto \n"$path"?'),
                                        const Text(''),
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
                                                await exportDatabaseFiles(dir);
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
                if (id == 2) {
                  /// import from here
                  ///
                }
                if (id == 1) {
                  AppWidgets.navigate(context, AppRoutes.liveTracking);
                }
              }),
          appBar: appBar(context),
          body: FileManager(
            controller: controller,
            builder: (context, snapshot) {
              controller
                  .isRootDirectory()
                  .then((value) => isBaseDir.value = value);
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
                          // open the folder
                          controller.openDirectory(entity);
                          // delete a folder
                          // await entity.delete(recursive: true);

                          // rename a folder
                          // await entity.rename("newPath");

                          // Check weather folder exists
                          // entity.exists();

                          // get date of file
                          // DateTime date = (await entity.stat()).modified;
                        } else {
                          // delete a file
                          // await entity.delete();

                          // rename a file
                          // await entity.rename("newPath");

                          // Check weather file exists
                          // entity.exists();

                          // get date of file
                          // DateTime date = (await entity.stat()).modified;

                          // get the size of the file
                          // int size = (await entity.stat()).size;
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
          padding: EdgeInsets.all(10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                  title: Text("Name"),
                  onTap: () {
                    controller.sortBy(SortBy.name);
                    Navigator.pop(context);
                  }),
              ListTile(
                  title: Text("Size"),
                  onTap: () {
                    controller.sortBy(SortBy.size);
                    Navigator.pop(context);
                  }),
              ListTile(
                  title: Text("Date"),
                  onTap: () {
                    controller.sortBy(SortBy.date);
                    Navigator.pop(context);
                  }),
              ListTile(
                  title: Text("type"),
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
      builder: (context) {
        TextEditingController folderName = TextEditingController();
        return Dialog(
          child: Container(
            padding: EdgeInsets.all(10),
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

                    Navigator.pop(context);
                  },
                  child: Text('Create Folder'),
                )
              ],
            ),
          ),
        );
      },
    );
  }
}
