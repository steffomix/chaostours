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

import 'package:chaostours/conf/app_routes.dart';
import 'package:flutter/material.dart';

import 'package:chaostours/database.dart';
import 'package:chaostours/screen.dart';
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

  static TableFields _table = TableFields.tables[0];

  final _scrollView = ScrollView();
  final _searchController = TextEditingController();
  final GlobalKey _bodyKey = GlobalKey();

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

  void onBottom(ScrollController c) {
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
    var tables = TableFields.tables;
    var list = <DropdownMenuEntry<TableFields>>[];
    for (var table in tables) {
      var item =
          DropdownMenuEntry<TableFields>(value: table, label: table.table);
      list.add(item);
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    var sc = Screen(context);
    var tableList = renderTableList();
    var table = renderTable();
    Future.microtask(() {
      var size = _bodyKey.currentContext?.size;
      if (size != null) {
        if (size.height < sc.height) {
          Future.delayed(const Duration(milliseconds: 200), loadRows);
        }
      }
    });

    _body = _scrollView.render(
        context,
        Wrap(
          spacing: 5,
          direction: Axis.vertical,
          key: _bodyKey,
          children: [
            Row(
              children: [
                const Padding(
                    padding: EdgeInsets.only(left: 20), child: Text('Table: ')),
                Padding(
                    padding: const EdgeInsets.only(left: 20),
                    child: DropdownMenu<TableFields>(
                      initialSelection: _table,
                      dropdownMenuEntries: tableList,
                      onSelected: (value) {
                        _table = value ?? TableFields.tables[0];
                        Future.microtask(() => AppWidgets.navigate(
                            context, AppRoutes.databaseExplorer));
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
            table
          ],
        ));
    return AppWidgets.scaffold(context, body: _body);
  }
}

typedef SingleScrollListener = void Function(ScrollController ctrl);
typedef DoubleScrollListener = void Function(
    {required ScrollController vertical, required ScrollController horizontal});

class ScrollView {
  final Logger logger = Logger.logger<ScrollView>();
  final _vertical = ScrollController();
  final _horizontal = ScrollController();
  SingleScrollListener? onTop;
  SingleScrollListener? onBottom;
  SingleScrollListener? onLeft;
  SingleScrollListener? onRight;
  DoubleScrollListener? onScroll;

  void _verticalListener() {
    onScroll?.call(vertical: _vertical, horizontal: _horizontal);
    if (_vertical.offset >= _vertical.position.maxScrollExtent &&
        !_vertical.position.outOfRange) {
      onBottom?.call(_vertical);
      logger.log("scrolled to bottom");
    }
    if (_vertical.offset <= _vertical.position.minScrollExtent &&
        !_vertical.position.outOfRange) {
      onTop?.call(_vertical);
      logger.log("scrolled to top");
    }
  }

  void _horizontalListener() {
    onScroll?.call(vertical: _horizontal, horizontal: _horizontal);
    if (_horizontal.offset >= _horizontal.position.maxScrollExtent &&
        !_horizontal.position.outOfRange) {
      onLeft?.call(_horizontal);
      logger.log("scrolled to right");
    }
    if (_horizontal.offset <= _horizontal.position.minScrollExtent &&
        !_horizontal.position.outOfRange) {
      onRight?.call(_horizontal);
      logger.log("scrolled to left");
    }
  }

  // ignore: empty_constructor_bodies
  ScrollView(
      {this.onTop, this.onBottom, this.onLeft, this.onRight, this.onScroll}) {
    _vertical.addListener(_verticalListener);
    _horizontal.addListener(_horizontalListener);
  }

  void dispose() {
    _vertical.dispose();
    _horizontal.dispose();
  }

  Widget render(BuildContext context, Widget child) {
    return Scrollbar(
        controller: _vertical,
        child: SingleChildScrollView(
            controller: _vertical,
            scrollDirection: Axis.vertical,
            child: Scrollbar(
                controller: _horizontal,
                child: SingleChildScrollView(
                    controller: _horizontal,
                    scrollDirection: Axis.horizontal,
                    child: child))));
  }
}
