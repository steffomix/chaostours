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

import 'package:chaostours/database/database.dart';
import 'package:chaostours/statistics/alias_statistics.dart';
import 'package:chaostours/view/trackpoint/widget_trackpoint_list.dart';
import 'package:flutter/material.dart';
import 'package:device_calendar/device_calendar.dart';

///
import 'package:chaostours/view/system/app_widgets.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/model/model_alias_group.dart';
import 'package:chaostours/conf/app_routes.dart';
import 'package:chaostours/calendar.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

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
  ModelAliasGroup? _model;
  int _countAlias = 0;
  Calendar? _calendar;
  final _titleUndoController = UndoHistoryController();

  final _descriptionUndoController = UndoHistoryController();

  Map<TableAliasGroup, bool Function()> fieldsMap = {};

  void generateMap(ModelAliasGroup model) {
    fieldsMap.clear();
    fieldsMap.addAll({
      TableAliasGroup.withCalendarHtml: () => model.calendarHtml,
      TableAliasGroup.withCalendarGps: () => model.calendarGps,
      TableAliasGroup.withCalendarTimeStart: () => model.calendarTimeStart,
      TableAliasGroup.withCalendarTimeEnd: () => model.calendarTimeEnd,
      TableAliasGroup.withCalendarDuration: () => model.calendarDuration,
      TableAliasGroup.withCalendarAddress: () => model.calendarAddress,
      TableAliasGroup.withCalendarFullAddress: () => model.calendarFullAddress,
      TableAliasGroup.withCalendarTrackpointNotes: () =>
          model.calendarTrackpointNotes,
      TableAliasGroup.withCalendarAlias: () => model.calendarAlias,
      TableAliasGroup.withCalendarAliasNearby: () => model.calendarAliasNearby,
      TableAliasGroup.withCalendarAliasNotes: () => model.calendarAliasNotes,
      TableAliasGroup.withCalendarAliasDescription: () =>
          model.calendarAliasDescription,
      TableAliasGroup.withCalendarUsers: () => model.calendarUsers,
      TableAliasGroup.withCalendarUserNotes: () => model.calendarUserNotes,
      TableAliasGroup.withCalendarUserDescription: () =>
          model.calendarUserDescription,
      TableAliasGroup.withCalendarTasks: () => model.calendarTasks,
      TableAliasGroup.withCalendarTaskNotes: () => model.calendarTaskNotes,
      TableAliasGroup.withCalendarTaskDescription: () =>
          model.calendarTaskDescription,
    });
  }

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
    var model = await ModelAliasGroup(title: '#${count + 1}').insert();
    return model;
  }

  Future<ModelAliasGroup?> loadAliasGroup(int? id) async {
    if (id == null) {
      _model = await createAliasGroup();
    } else {
      _model = await ModelAliasGroup.byId(id);
    }
    if (_model == null && mounted) {
      if (mounted) {
        Future.microtask(() => Navigator.pop(context));
      }
      throw 'Group #$id not found';
    } else {
      _countAlias = await _model!.aliasCount();
      if (await Permission.calendarFullAccess.isGranted) {
        _calendar = await AppCalendar().calendarById(_model!.idCalendar);
      }
      generateMap(_model!);
      return _model;
    }
  }

  @override
  Widget build(BuildContext context) {
    int? id = ModalRoute.of(context)?.settings.arguments as int?;

    return FutureBuilder<ModelAliasGroup?>(
      future: loadAliasGroup(id),
      builder: (context, snapshot) {
        return AppWidgets.checkSnapshot(context, snapshot) ?? body();
      },
    );
  }

  Widget body() {
    return scaffold(_displayMode == _DisplayMode.editGroup
        ? editGroup()
        : AppWidgets.calendarSelector(
            context: context,
            selectedCalendar: _calendar,
            onSelect: (cal) {
              _model!.idCalendar = cal.id ?? '';
              _model!.update().then(
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
          var model = await ModelAliasGroup(title: '#$count').insert();
          if (mounted) {
            await Navigator.pushNamed(context, AppRoutes.editAliasGroup.route,
                arguments: model.id);
            render();
          }
        }));
  }

  Widget editGroup() {
    return ListView(padding: const EdgeInsets.all(5), children: [
      /// Trackpoints button
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: FilledButton(
                  onPressed: () => Navigator.pushNamed(
                      context, AppRoutes.listTrackpoints.route,
                      arguments: TrackpointListArguments.aliasGroup
                          .arguments(_model!.id)),
                  child: const Text('Trackpoints'))),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: FilledButton(
                  onPressed: () async {
                    var stats = await AliasStatistics.groupStatistics(_model!);

                    if (mounted) {
                      AppWidgets.statistics(context, stats: stats,
                          reload: (DateTime start, DateTime end) async {
                        return await AliasStatistics.groupStatistics(
                            stats.model,
                            start: start,
                            end: end);
                      });
                    }
                  },
                  child: const Text('Statistics')))
        ],
      ),

      /// groupname
      ListTile(
          dense: true,
          trailing: ValueListenableBuilder<UndoHistoryValue>(
            valueListenable: _titleUndoController,
            builder: (context, value, child) {
              return IconButton(
                icon: const Icon(Icons.undo),
                onPressed: value.canUndo
                    ? () {
                        _titleUndoController.undo();
                      }
                    : null,
              );
            },
          ),
          title: Container(
              padding: const EdgeInsets.all(10),
              child: TextField(
                decoration:
                    const InputDecoration(label: Text('Alias Group Name')),
                onChanged: ((value) {
                  _model!.title = value;
                  _model!.update();
                }),
                maxLines: 3,
                minLines: 3,
                controller: TextEditingController(text: _model?.title),
              ))),
      AppWidgets.divider(),

      /// notes
      ListTile(
          dense: true,
          trailing: ValueListenableBuilder<UndoHistoryValue>(
            valueListenable: _descriptionUndoController,
            builder: (context, value, child) {
              return IconButton(
                icon: const Icon(Icons.undo),
                onPressed: value.canUndo
                    ? () {
                        _descriptionUndoController.undo();
                      }
                    : null,
              );
            },
          ),
          title: Container(
              padding: const EdgeInsets.all(10),
              child: TextField(
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(label: Text('Notizen')),
                maxLines: null,
                minLines: 3,
                controller: TextEditingController(text: _model?.description),
                onChanged: (value) {
                  _model!.description = value.trim();
                  _model!.update();
                },
              ))),
      AppWidgets.divider(),

      /// deleted
      ListTile(
          title: const Text('Active'),
          subtitle: const Text('This Group is active and visible'),
          leading: AppWidgets.checkbox(
            value: _model!.isActive,
            onChanged: (val) {
              _model!.isActive = val ?? false;
              _model!.update();
            },
          )),

      AppWidgets.divider(),

      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: FilledButton(
          child: Text('Show $_countAlias Aliases from this group'),
          onPressed: () => Navigator.pushNamed(
                  context, AppRoutes.listAliasesFromAliasGroup.route,
                  arguments: _model!.id)
              .then((value) {
            render();
          }),
        ),
      ),

      AppWidgets.divider(),

      /// calendar
      Column(children: [
        Text('Calendar', style: Theme.of(context).textTheme.bodyLarge),
        Column(mainAxisSize: MainAxisSize.min, children: [
          _calendar == null
              ? FilledButton(
                  onPressed: () {
                    _displayMode = _DisplayMode.selectCalendar;
                    render();
                  },
                  child: const Text('add Calendar'),
                )
              : ListTile(
                  leading: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () async {
                        _model!.idCalendar = '';
                        await _model!.update();
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
                      '${_calendar?.name ?? '-'}\n${_calendar?.accountName ?? ''}'),
                  subtitle: Text('Default Calendar',
                      style: _calendar?.isDefault ?? false
                          ? null
                          : const TextStyle(
                              decoration: TextDecoration.lineThrough)),
                )
        ])
      ]),
      ...calendarOptions(),
    ]);
  }

  Widget renderCalendarOption({
    required TableAliasGroup field,
    required String title,
    required String description,
  }) {
    return ListTile(
      trailing: AppWidgets.checkbox(
          value: fieldsMap[field]?.call() ?? false,
          onChanged: (bool? state) {
            state = (state ?? false);
            if (state == true && !_privacyRespected) {
              AppWidgets.dialog(
                  context: context,
                  title: const Text('Privacy Compliance Warning'),
                  contents: [
                    const Text(
                        'Attention: To ensure privacy compliance and data integrity, it is mandatory to confirm that you have read, understood, and taken necessary steps to adhere to our privacy advisory. Without checking the compliance checkbox, the app will not post any data to your calendar.'),
                    const Text(
                        'Please review the privacy advisory and confirm your understanding by checking the compliance checkbox provided. This is a critical step to guarantee that your usage aligns with privacy considerations.'),
                    ListTile(
                        leading: AppWidgets.checkbox(
                            value: _privacyRespected,
                            onChanged: (bool? state) =>
                                _privacyRespected = state ?? false),
                        title: const Text(
                            'I have read, understood, and ensured privacy compliance.')),
                    const Text(
                        'Thank you for your cooperation in maintaining a secure and respectful environment within our app. If you have any questions or concerns, feel free to reach out to our support team for assistance.'),
                  ],
                  buttons: [
                    FilledButton(
                      child: const Text('OK'),
                      onPressed: () {
                        Navigator.pop(context);
                        setState(() {});
                      },
                    )
                  ]);
            } else {
              updateField(field, state);
            }
          }),
      title: Text(field.name),
      subtitle: Text(field.toString()),
    );
  }

  List<Widget> calendarOptions() {
    return _calendar == null
        ? []
        : [
            AppWidgets.divider(),
            ...privacyWarning(),
            AppWidgets.divider(),
            Center(
                child: Text('Calendar Options',
                    style: Theme.of(context).textTheme.bodyLarge)),
            ...TableAliasGroup.calendarFields().map(
              (e) => renderCalendarOption(field: e, title: '', description: ''),
            )
          ];

    ///
    ///
    /// withCalendarHtml

    ///
    ///
    /// withCalendarGps

    ///
    ///
    /// withCalendarTimeStart

    ///
    ///
    /// withCalendarTimeEnd

    ///
    ///
    /// withCalendarDuration

    ///
    ///
    /// withCalendarAddress

    ///
    ///
    /// withCalendarFullAddress

    ///
    ///
    /// withCalendarTrackpointNotes

    ///
    ///
    /// withCalendarAlias

    ///
    ///
    /// withCalendarAliasNearby

    ///
    ///
    /// withCalendarAliasNotes

    ///
    ///
    /// withCalendarAliasDescription

    ///
    ///
    /// withCalendarUsers

    ///
    ///
    /// withCalendarUserNotes

    ///
    ///
    /// withCalendarUserDescription

    ///
    ///
    /// withCalendarTasks

    ///
    ///
    /// withCalendarTaskNotes

    ///
    ///
    /// withCalendarTaskDescription
  }

  Future<void> updateField(TableAliasGroup field, bool value) async {
    switch (field) {
      case TableAliasGroup.withCalendarHtml:
        _model?.calendarHtml = value;
        break;
      case TableAliasGroup.withCalendarGps:
        _model?.calendarGps = value;
        break;
      case TableAliasGroup.withCalendarTimeStart:
        _model?.calendarTimeStart = value;
        break;
      case TableAliasGroup.withCalendarTimeEnd:
        _model?.calendarTimeEnd = value;
        break;
      case TableAliasGroup.withCalendarDuration:
        _model?.calendarDuration = value;
        break;
      case TableAliasGroup.withCalendarAddress:
        _model?.calendarAddress = value;
        break;
      case TableAliasGroup.withCalendarFullAddress:
        _model?.calendarFullAddress = value;
        break;
      case TableAliasGroup.withCalendarTrackpointNotes:
        _model?.calendarTrackpointNotes = value;
        break;
      case TableAliasGroup.withCalendarAlias:
        _model?.calendarAlias = value;
        break;
      case TableAliasGroup.withCalendarAliasNearby:
        _model?.calendarAliasNearby = value;
        break;
      case TableAliasGroup.withCalendarAliasNotes:
        _model?.calendarAliasNotes = value;
        break;
      case TableAliasGroup.withCalendarAliasDescription:
        _model?.calendarAliasDescription = value;
        break;
      case TableAliasGroup.withCalendarUsers:
        _model?.calendarUsers = value;
        break;
      case TableAliasGroup.withCalendarUserNotes:
        _model?.calendarUserNotes = value;
        break;
      case TableAliasGroup.withCalendarUserDescription:
        _model?.calendarUserDescription = value;
        break;
      case TableAliasGroup.withCalendarTasks:
        _model?.calendarTasks = value;
        break;
      case TableAliasGroup.withCalendarTaskNotes:
        _model?.calendarTaskNotes = value;
        break;
      case TableAliasGroup.withCalendarTaskDescription:
        _model?.calendarTaskDescription = value;
        break;

      default:
        logger.error('field $field not implemented', StackTrace.current);
    }
    await _model?.update();
  }

  bool _privacyRespected = false;

  List<Widget> privacyWarning() {
    return [
      Text('Important Privacy Advisory',
          style: Theme.of(context).textTheme.headlineSmall),
      const Text(
          'Please be aware that certain device calendars can be set to public for everyone. ',
          style: TextStyle(
              decoration: TextDecoration.underline,
              fontWeight: FontWeight.w900)),
      const Text(
          'This app does not have access to your device calendar settings. Therefore, it is crucial to verify your device calendar settings before selecting any content options from the list below.'),
      const Text(
          'We emphasize the importance of respecting the privacy of others and yourself — do not add content to your calendar without explicit consent, as it may impact your and others privacy. Additionally, be mindful that this app writes data to your calendar while the app is closed and running in the background.'),
      const Text(
          'Before proceeding, we strongly recommend reviewing your device calendar\'s privacy policy. Understanding these policies will help you make informed decisions when checking any content options.'),
      const Text(
          'If you are unsure about locating your calendar or need assistance with settings, tap the button below to open and review your device calendar settings.'),
      Center(
          child: FilledButton(
        child: const Text('Open device calendar'),
        onPressed: () async {
          var success =
              await launchUrl(Uri.parse('content://com.android.calendar'));
          if (!success && mounted) {
            AppWidgets.dialog(
                context: context,
                title: const Text('Calendar Opening Error'),
                contents: [
                  const Text(
                      'We regret to inform you that an issue occurred while attempting to open your device calendar. If the calendar did not open, please consider the following steps:'),
                  const ListTile(
                    title: Text('1: Check Installation and Activation:'),
                    subtitle: Text(
                        'Ensure that your calendar is properly installed and activated on your device. Verify its functionality by opening it manually.'),
                  ),
                  const ListTile(
                    title: Text('2: Device Calendar Troubleshooting:'),
                    subtitle: Text(
                        'If the issue persists, it\'s advisable to check for any updates or settings that might be affecting the calendar\'s operation. Refer to your device\'s user manual or support resources for guidance.'),
                  ),
                  const ListTile(
                    title: Text('3: Service Point Assistance:'),
                    subtitle: Text(
                        'If the problem still persists, we recommend seeking assistance from a service point or authorized support center for your device. Professionals at these service points can provide specialized help in resolving issues related to your device calendar.'),
                  ),
                  const Text(
                      'We apologize for any inconvenience this may have caused. If you encounter further difficulties, please feel free to contact our support team for additional assistance.')
                ],
                buttons: [
                  FilledButton(
                    child: const Text('Cancel'),
                    onPressed: () => Navigator.pop(context),
                  ),
                  FilledButton(
                    child: const Text('Support'),
                    onPressed: () => launchUrl(Uri.parse(
                        'https://github.com/steffomix/chaostours/issues')),
                  )
                ]);
          }
        },
      )),
      const Text(
          'Your commitment to privacy is greatly appreciated, and thank you for using our app responsibly.\n\n'),
      Text('Confirmation', style: Theme.of(context).textTheme.headlineSmall),
      const Text(
          'I confirm that I have read and understood the privacy advisory.\n'
          'I have checked and adjusted my device calendar settings before selecting any content options from the list.\n'
          'I acknowledge the importance of respecting the privacy of others and myself and affirm that I will not add any content to my calendar without explicit consent, ensuring it does not compromise anyone\'s privacy. Additionally, I am aware that this app writes data to my calendar while the app is closed and running in the background.\n'
          'I have carefully read my device calendar\'s privacy policy.'),
      const Text(
          'By checking this box, I confirm that I have taken all necessary steps to use this app responsibly and in compliance with privacy considerations.'),
      ListTile(
          leading: AppWidgets.checkbox(
              value: _privacyRespected,
              onChanged: (bool? state) => _privacyRespected = state ?? false),
          title: const Text(
              'I have read, understood, and ensured privacy compliance.'))
    ];
  }
}
