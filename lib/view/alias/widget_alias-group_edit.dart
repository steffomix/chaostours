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
import 'package:device_calendar/device_calendar.dart';

///
import 'package:chaostours/view/app_widgets.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/model/model_alias_group.dart';
import 'package:chaostours/conf/app_routes.dart';
import 'package:chaostours/calendar.dart';

enum _DisplayMode {
  selectCalendar,
  editGroup;
}

class WidgetAliasGroupEdit extends StatefulWidget {
  const WidgetAliasGroupEdit({super.key});

  @override
  State<WidgetAliasGroupEdit> createState() => _WidgetAliasGroupEdit();
}

class _WidgetAliasGroupEdit extends State<WidgetAliasGroupEdit> {
  // ignore: unused_field
  static final Logger logger = Logger.logger<WidgetAliasGroupEdit>();
  _DisplayMode _displayMode = _DisplayMode.editGroup;
  ModelAliasGroup? _modelAlias;
  Calendar? _calendar;
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void dispose() {
    super.dispose();
  }

  void render() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<ModelAliasGroup> createAliasGroup() async {
    var count = await ModelAliasGroup.count();
    var model = ModelAliasGroup(title: '#${count + 1}');
    await ModelAliasGroup.insert(model);
    return model;
  }

  Future<ModelAliasGroup?> loadAliasGroup(int? id) async {
    if (id == null) {
      return await createAliasGroup();
    }
    var model = await ModelAliasGroup.byId(id);
    if (model == null) {
      if (mounted) {
        Navigator.pop(context);
      }
      return null;
    }
    _calendar = await AppCalendar().calendarById(model.idCalendar);
    return model;
  }

  @override
  Widget build(BuildContext context) {
    int? id = ModalRoute.of(context)?.settings.arguments as int?;

    return FutureBuilder<ModelAliasGroup?>(
      future: loadAliasGroup(id),
      builder: (context, snapshot) {
        Widget? loading = AppWidgets.checkSnapshot(context, snapshot);
        if (loading != null) {
          return AppWidgets.scaffold(context,
              body: AppWidgets.loading(const Text('Loading Group...')));
        }
        var model = snapshot.data!;
        return body(model);
      },
    );
  }

  Widget body(ModelAliasGroup model) {
    _modelAlias = model;
    _titleController.text = model.title;
    _notesController.text = model.description;
    return scaffold(_displayMode == _DisplayMode.editGroup
        ? editGroup(model)
        : AppWidgets.calendarSelector(
            context: context,
            selectedCalendar: _calendar,
            onSelect: (cal) {
              _modelAlias?.idCalendar = cal.id ?? '';
              _modelAlias?.update().then(
                (value) {
                  _displayMode = _DisplayMode.editGroup;
                  render();
                },
              );
            },
          ));
  }

  Widget scaffold(Widget body) {
    return AppWidgets.scaffold(context,
        title: 'Edit Alias Group',
        body: body,
        navBar: AppWidgets.navBarCreateItem(context, name: 'Alias Group',
            onCreate: () async {
          var count = (await ModelAliasGroup.count()) + 1;
          var model =
              await ModelAliasGroup.insert(ModelAliasGroup(title: '#$count'));
          if (mounted) {
            await Navigator.pushNamed(context, AppRoutes.editAliasGroup.route,
                arguments: model.id);
            render();
          }
        }));
  }

  Widget editGroup(ModelAliasGroup model) {
    return ListView(children: [
      /// aliasname
      Container(
          padding: const EdgeInsets.all(10),
          child: TextField(
            decoration: const InputDecoration(label: Text('Alias Group Name')),
            onChanged: ((value) {
              model.title = value;
              model.update();
            }),
            maxLines: 3,
            minLines: 3,
            controller: _titleController,
          )),
      AppWidgets.divider(),

      /// notes
      Container(
          padding: const EdgeInsets.all(10),
          child: TextField(
            keyboardType: TextInputType.multiline,
            decoration: const InputDecoration(label: Text('Notizen')),
            maxLines: null,
            minLines: 3,
            controller: _notesController,
            onChanged: (value) {
              model.description = value.trim();
              model.update();
            },
          )),
      AppWidgets.divider(),

      /// calendar
      Column(children: [
        const Text('Calendar'),
        Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
              leading: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () async {
                    model.idCalendar = '';
                    await model.update();
                    render();
                  }),
              trailing: IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {
                  _displayMode = _DisplayMode.selectCalendar;
                  render();
                },
              ),
              title: Text(
                  '${_calendar?.name ?? '-'}\n${_calendar?.accountName ?? ''}')),
        ])
      ]),
      AppWidgets.divider(),

      /// deleted
      ListTile(
          title: const Text('Active'),
          subtitle: const Text(
            'This Group is active and visible',
            softWrap: true,
          ),
          leading: Checkbox(
            value: model.isActive,
            onChanged: (val) {
              model.isActive = val ?? false;
              model.update().then((value) => render());
            },
          )),

      AppWidgets.divider(),

      ElevatedButton(
        child: const Text('Show Aliases from this group'),
        onPressed: () => Navigator.pushNamed(
                context, AppRoutes.listAliasesFromAliasGroup.route,
                arguments: _modelAlias?.id)
            .then((value) {
          render();
        }),
      )
    ]);
  }
}
