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

import 'package:chaostours/database.dart';
import 'package:chaostours/screen.dart';
import 'package:chaostours/scroll_controller.dart';
import 'package:chaostours/model/model.dart';
import 'package:chaostours/view/app_widgets.dart';
import 'package:chaostours/logger.dart';

class WidgetDatabaseExplorer extends StatefulWidget {
  const WidgetDatabaseExplorer({super.key});

  @override
  State<WidgetDatabaseExplorer> createState() => _DatabaseExplorer();
}

typedef ModelRow = Map<String, Object?>;

class _DatabaseExplorer extends State<WidgetDatabaseExplorer> {
  static final Logger logger = Logger.logger<WidgetDatabaseExplorer>();

  TableFields _table = TableFields.tables[0];

  final _searchController = TextEditingController();

  //final _loader = Loader(key: GlobalKey());
  final _scrollView = ScrollEdgeController(key: GlobalKey());

  // dataTable data
  final _dataTableHeader = <DataColumn>[];
  final _dataRows = <DataRow>[];
  // default body
  Widget _body = AppWidgets.loading('No _body yet created...');

  // chunks to load
  static const int _limit = 50;
  // offset of loading from database
  int get _offset {
    return _dataRows.length;
  }

  // data loader
  bool _isLoadingData = false;
  bool _hadLoadRequest = false;

  @override
  void initState() {
    renderTableHeader();
    loadRows();
    _scrollView.onBottom = onBottom;
    super.initState();
  }

  Future<void> onBottom() async {
    loadRows();
  }

  @override
  void dispose() {
    _scrollView.dispose();
    super.dispose();
  }

  void render() {
    if (mounted) {
      setState(() {});
    }
  }

  void reset() {
    _dataRows.clear();
    renderTableHeader();
    render();
    loadRows();
  }

  Future<void> loadRows() async {
    try {
      if (_isLoadingData) {
        // remember request
        _hadLoadRequest = true;
        return;
      }

      _isLoadingData = true;
      // check if all is loaded

      logger.log('load count');
      var count = await Model.count(_table, search: _searchController.text);
      if (count <= _dataRows.length) {
        _isLoadingData = false;
        return;
      }

      logger.log('load rows');
      // load next chunk of data
      var rows = await Model.select(_table,
          offset: _offset, limit: _limit, search: _searchController.text);
      _isLoadingData = false;

      // render data
      for (var row in rows) {
        _dataRows.add(renderRow(row));
      }
      if (_hadLoadRequest) {
        _hadLoadRequest = false;
        logger.log('exec load rquest');
        loadRows();
      }
      render();
    } catch (e, stk) {
      _isLoadingData = false;
      logger.error('load rows: $e', stk);
    }
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

  void renderTableHeader() {
    _dataTableHeader.clear();
    var cells = <DataCell>[];
    for (var c in _table.columns) {
      var parts = c.split('.');
      _dataTableHeader.add(DataColumn(label: Text(parts.last)));
      cells.add(DataCell(Text(parts.last)));
    }
  }

  Widget renderTable() {
    return DataTable(
        //dataRowMinHeight: 200,
        //dataRowMaxHeight: 400,
        columns: _dataTableHeader,
        rows: _dataRows);
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
  Widget build(BuildContext context) {
    Future.delayed(const Duration(milliseconds: 100), () {
      var size = _scrollView.key.currentContext?.size;
      if (size != null) {
        if (size.height < Screen(context).height) {
          Future.delayed(const Duration(milliseconds: 200), loadRows);
        }
      }
    });

    _body = _scrollView.renderDouble(
        context,
        Wrap(
          spacing: 5,
          direction: Axis.vertical,
          key: _scrollView.key,
          children: [
            Row(
              children: [
                const Padding(
                    padding: EdgeInsets.only(left: 20), child: Text('Table: ')),
                Padding(
                    padding: const EdgeInsets.only(left: 20),
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
                        Future.delayed(
                            const Duration(milliseconds: 100), reset);
                        /*
                        Future.delayed(
                            const Duration(milliseconds: 100),
                            () => AppWidgets.navigate(
                                context, AppRoutes.databaseExplorer));
                                */
                      },
                    )),
              ],
            ),
            SizedBox(
                width: 400,
                child: ListTile(
                    leading: const Icon(Icons.search),
                    trailing: IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.text = '';
                        reset();
                      },
                    ),
                    title: TextField(
                      controller: _searchController,
                      onChanged: (value) {
                        reset();
                      },
                    ))),
            renderTable()
          ],
        ));
    return AppWidgets.scaffold(context, body: _body);
  }
}
