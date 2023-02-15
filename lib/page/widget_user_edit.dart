import 'package:chaostours/widget/widgets.dart';
import 'package:flutter/material.dart';

///
import 'package:chaostours/logger.dart';
import 'package:chaostours/model/model_user.dart';

class WidgetUserEdit extends StatefulWidget {
  const WidgetUserEdit({super.key});

  @override
  State<WidgetUserEdit> createState() => _WidgetUserEdit();
}

class _WidgetUserEdit extends State<WidgetUserEdit> {
  static final Logger logger = Logger.logger<WidgetUserEdit>();

  ModelUser? _user;
  bool? _deleted;
  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final id = ModalRoute.of(context)!.settings.arguments as int;
    bool create = id <= 0;
    _user ??= create
        ? ModelUser(user: '', deleted: 0, notes: '')
        : ModelUser.getUser(id);
    ModelUser user = _user!;
    _deleted ??= user.deleted > 0;
    bool deleted = _deleted!;

    return AppWidgets.scaffold(context,
        body: ListView(children: [
          /// ok button
          IconButton(
            icon: Icon(create ? Icons.add : Icons.done),
            onPressed: () {
              if (user.user.isEmpty) {
                user.user = 'Person #${user.id}';
              }
              create ? ModelUser.insert(user) : ModelUser.write();
              Navigator.pop(context);
              Navigator.pushNamed(context, AppRoutes.listUsers.route);
            },
          ),

          /// username
          Container(
              padding: const EdgeInsets.all(10),
              child: TextField(
                decoration: const InputDecoration(label: Text('Name')),
                onChanged: ((value) {
                  user.user = value;
                }),
                maxLines: 1,
                minLines: 1,
                controller: TextEditingController(text: user.user),
              )),

          /// notes
          Container(
              padding: const EdgeInsets.all(10),
              child: TextField(
                decoration: const InputDecoration(label: Text('Notizen')),
                maxLines: null,
                minLines: 3,
                controller: TextEditingController(text: user.notes),
              )),

          /// deleted
          ListTile(
              title: const Text('Deaktiviert / gelöscht'),
              subtitle: const Text(
                'Definiert ob diese Person gelistet und auswählbar ist',
                softWrap: true,
              ),
              leading: Checkbox(
                value: deleted,
                onChanged: (val) {
                  setState(() {
                    _deleted = val;
                  });
                  user.deleted = (val ?? false) ? 1 : 0;
                },
              ))
        ]));
  }
}
