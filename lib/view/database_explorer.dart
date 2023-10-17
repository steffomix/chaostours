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

import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:chaostours/model/model.dart';

class DatabaseExplorer extends StatefulWidget {
  const DatabaseExplorer({super.key});

  @override
  State<DatabaseExplorer> createState() => _DatabaseExplorer();
}

class _DatabaseExplorer extends State<DatabaseExplorer> {
  @override
  void dispose() {
    super.dispose();
  }

  int _selectedTable = 0;

  // items per page
  static const int _limit = 30;

  final PagingController<int, Map<String, Object?>> _pagingController =
      PagingController(firstPageKey: 0);

  @override
  void initState() {
    _pagingController.addPageRequestListener(_fetchPage);
    super.initState();
  }

  void _fetchPage(int offset) async {
    var newItems = await Model.select(Model.tables[_selectedTable],
        limit: _limit, offset: offset);

    if (newItems.length < _limit) {
      _pagingController.appendLastPage(newItems);
    } else {
      _pagingController.appendPage(newItems, offset + newItems.length);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
