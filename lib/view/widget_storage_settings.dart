import 'package:flutter/material.dart';
import 'package:file_manager/file_manager.dart';
import 'dart:io';

///
import 'package:chaostours/file_handler.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/view/app_widgets.dart';
import 'package:confirm_dialog/confirm_dialog.dart';

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
  void initState() {}

  FileManagerController controller = FileManagerController();
  @override
  Widget build(BuildContext context) {
    return AppWidgets.scaffold(
      context,
      body: FileManager(
        controller: controller,
        builder: (context, snapshot) {
          final List<FileSystemEntity> entities = snapshot;
          return ListView.builder(
            itemCount: entities.length,
            itemBuilder: (context, index) {
              return Card(
                child: ListTile(
                  leading: FileManager.isFile(entities[index])
                      ? const Icon(Icons.feed_outlined)
                      : const Icon(Icons.folder),
                  title: Text(FileManager.basename(entities[index])),
                  onTap: () {
                    if (FileManager.isDirectory(entities[index])) {
                      controller
                          .openDirectory(entities[index]); // open directory
                    } else {
                      // Perform file-related tasks.
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
