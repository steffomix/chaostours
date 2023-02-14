import 'package:chaostours/widget/widgets.dart';
import 'package:flutter/material.dart';

///
import 'package:chaostours/logger.dart';
import 'package:chaostours/model/model_user.dart';

class WidgetUserList extends StatefulWidget {
  const WidgetUserList({super.key});

  @override
  State<WidgetUserList> createState() => _WidgetUserList();
}

class _WidgetUserList extends State<WidgetUserList> {
  static final Logger logger = Logger.logger<WidgetUserList>();

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    List<ListTile> users = ModelUser.getAll().map((ModelUser user) {
      return ListTile(
          title: Text(user.user),
          subtitle: Text(user.notes),
          leading: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.editUser.route,
                    arguments: user.id);
              }));
    }).toList();

    return ListView(children: users);
  }
}
