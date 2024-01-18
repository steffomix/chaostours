/*
Copyright 2023 Stefan Brinkmann <st.brinkmann@gmail.com>

Licensed under the Apache License, Version 2.0 (the License);
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an AS IS BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

import 'package:chaostours/database/database.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/model/model_alias_group.dart';
import 'package:chaostours/view/system/app_widgets.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class WidgetCalendarOptions extends StatefulWidget {
  const WidgetCalendarOptions({super.key});

  @override
  State<WidgetCalendarOptions> createState() => _WidgetCalendarOptionsState();
}

class _WidgetCalendarOptionsState extends State<WidgetCalendarOptions> {
  static final Logger logger = Logger.logger<WidgetCalendarOptions>();

  ModelAliasGroup? _model;
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
      TableAliasGroup.withCalendarNearbyAliasDescription: () =>
          model.calendarNearbyAliasDescription,
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

  Future<ModelAliasGroup?> loadAlias(int id) async {
    _model = await ModelAliasGroup.byId(id);
    if (_model == null) {
      if (mounted) {
        Future.microtask(() => Navigator.pop(context));
      }
      throw ('Model not found');
    }
    generateMap(_model!);
    return _model;
  }

  @override
  Widget build(BuildContext context) {
    int id = ModalRoute.of(context)?.settings.arguments as int? ?? 0;

    return FutureBuilder(
      future: loadAlias(id),
      builder: (context, snapshot) {
        return AppWidgets.checkSnapshot(context, snapshot) ?? body();
      },
    );
  }

  Widget renderItem({
    required TableAliasGroup field,
    required String title,
    required String description,
  }) {
    return ListTile(
      trailing: AppWidgets.checkbox(
          value: fieldsMap[field]?.call() ?? false,
          onChanged: (bool? state) {
            updateField(field, state ?? false);
          }),
      title: Text(field.name),
      subtitle: Text(field.toString()),
    );
  }

  Widget body() {
    return AppWidgets.scaffold(context,
        title: 'Calendar Options',
        body: ListView(padding: const EdgeInsets.all(5), children: [
          ...TableAliasGroup.calendarFields().map(
            (e) => renderItem(field: e, title: '', description: ''),
          )

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
        ]));
  }

  void updateField(TableAliasGroup field, bool value) {
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
      case TableAliasGroup.withCalendarNearbyAliasDescription:
        _model?.calendarNearbyAliasDescription = value;
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
  }

  bool _privacyRespected = false;

  List<Widget> privacyWarning() {
    return [
      const Text('Important Privacy Advisory'),
      const Text(
          'Please be aware that certain device calendars can be set to public for everyone. This app does not have access to your device calendar settings. Therefore, it is crucial to verify your device calendar settings before selecting any content options from the list below.'),
      const Text(
          'We emphasize the importance of respecting the privacy of others — do not add content to your calendar without their explicit consent, as it may impact their privacy. Additionally, be mindful that this app writes data to your calendar while the app is closed and running in the background.'),
      const Text(
          'Before proceeding, we strongly recommend reviewing your device calendar\'s privacy policy. Understanding these policies will help you make informed decisions when checking any content options.'),
      const Text(
          'If you are unsure about locating your calendar or need assistance with settings, tap the button below to open and review your device calendar settings.'),
      Center(
          child: FilledButton(
        child: const Text('Open device calendar'),
        onPressed: () async {
          launchUrl(Uri.parse('content://com.android.calendar'));
        },
      )),
      const Text(
          'Your commitment to privacy is greatly appreciated, and thank you for using our app responsibly.'),
      AppWidgets.divider(),
      const Text(
          'I confirm that I have read and understood the privacy advisory.\n'
          'I have checked and adjusted my device calendar settings before selecting any content options from the list.\n'
          'I acknowledge the importance of respecting the privacy of others and affirm that I will not add any content to my calendar without explicit consent, ensuring it does not compromise anyone\'s privacy. Additionally, I am aware that this app writes data to my calendar while running in the background.\n'
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
