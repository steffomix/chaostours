import 'package:chaostours/widget/widgets.dart';
import 'package:flutter/material.dart';

///
import 'package:chaostours/logger.dart';
import 'package:chaostours/model/model_alias.dart';

class WidgetAliasList extends StatefulWidget {
  const WidgetAliasList({super.key});

  @override
  State<WidgetAliasList> createState() => _WidgetAliasList();
}

class _WidgetAliasList extends State<WidgetAliasList> {
  static final Logger logger = Logger.logger<WidgetAliasList>();

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    List<ListTile> alias = ModelAlias.getAll().map((ModelAlias alias) {
      return ListTile(
          title: Text(alias.alias),
          subtitle: Text(alias.notes),
          leading: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.editAlias.route,
                    arguments: alias.id);
              }));
    }).toList();

    return AppWidgets.scaffold(context, body: ListView(children: alias));
  }
}
