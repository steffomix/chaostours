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

///
import 'package:chaostours/database.dart';
// import 'package:chaostours/logger.dart';
import 'package:chaostours/view/app_widgets.dart';
import 'package:chaostours/model/model.dart';
import 'package:chaostours/view/app_base_widget.dart';

typedef ModelRow = Map<String, Object?>;

class WidgetDatabaseExplorer extends BaseWidget {
  const WidgetDatabaseExplorer({Key? key}) : super(key: key);
  @override
  State<WidgetDatabaseExplorer> createState() => _WidgetDatabaseExplorer();
}

class _WidgetDatabaseExplorer extends BaseWidgetState<WidgetDatabaseExplorer>
    implements BaseWidgetPattern {
  //static final Logger logger = Logger.logger<WidgetDatabaseExplorer>();
  TableFields _table = TableFields.tables[0];

  final _searchController = TextEditingController();

  @override
  Future<void> initialize(BuildContext context, Object? args) async {}

  @override
  int loaderLimit() => 20;

  double headerHight = 100;

  final List<DataRow> loadedItems = [];

  @override
  Future<int> load({required int offset, int limit = 20}) async {
    final rows = (await Model.select(_table,
        limit: limit, offset: offset, search: _searchController.text));

    loadedItems.addAll(rows.map(
      (e) => renderRow(e),
    ));
    return rows.length;
  }

  @override
  Future<void> resetLoader() async {
    await super.resetLoader();
    loadedItems.clear();
    render();
  }

  List<DataColumn> renderTableHeader() {
    final headers = <DataColumn>[];
    var cells = <DataCell>[];
    for (var c in _table.columns) {
      var parts = c.split('.');
      headers.add(DataColumn(label: Text(parts.last)));
      cells.add(DataCell(Text(parts.last)));
    }
    return headers;
  }

  List<DropdownMenuEntry<TableFields>> renderTableList() {
    var list = <DropdownMenuEntry<TableFields>>[];
    var i = 1;
    for (var table in TableFields.tables) {
      var item = DropdownMenuEntry<TableFields>(
          value: table, label: '#$i ${table.table}');
      list.add(item);
      i++;
    }
    return list;
  }

  @override
  List<Widget> renderHeader(BoxConstraints constraints) {
    return <Widget>[
      Row(children: [
        const Padding(padding: EdgeInsets.all(10), child: Text('Table: ')),
        Padding(
            padding: const EdgeInsets.all(10),
            child: DropdownMenu<TableFields>(
              enableSearch: true,
              trailingIcon: const Icon(Icons.arrow_left_outlined),
              selectedTrailingIcon: const Icon(Icons.arrow_left),
              initialSelection: _table,
              dropdownMenuEntries: renderTableList(),
              onSelected: (value) {
                if (value == null) {
                  return;
                }
                _table = value;
                Future.delayed(const Duration(milliseconds: 100), () {
                  resetLoader();
                });
                /*
                        Future.delayed(
                            const Duration(milliseconds: 100),
                            () => AppWidgets.navigate(
                                context, AppRoutes.databaseExplorer));
                                */
              },
            ))
      ]),
      ListTile(
          leading: const Icon(Icons.search),
          trailing: IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              _searchController.text = '';
              resetLoader();
            },
          ),
          title: TextField(
            controller: _searchController,
            onChanged: (value) {
              resetLoader();
            },
          )),
      AppWidgets.divider()
    ];
  }

  DataRow renderRow(ModelRow row) {
    var cells = <DataCell>[];
    for (var k in row.keys) {
      String v = row[k]?.toString() ?? 'NULL';
      if (v.length > 40) {
        v = '${v.substring(0, 20)}...';
      }
      cells.add(DataCell(Text(
        v,
      )));
    }
    return DataRow(cells: cells);
  }

  @override
  List<Widget> renderBody(BoxConstraints constraints) {
    var tb = DataTable(columns: renderTableHeader(), rows: loadedItems);
    return <Widget>[tb];
  }

  @override
  Scaffold renderScaffold(Widget body) {
    return AppWidgets.scaffold(context, body: body);
  }
}
