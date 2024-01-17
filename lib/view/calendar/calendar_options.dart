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
  }
}
