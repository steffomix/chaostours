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

///
import 'package:chaostours/screen.dart';
import 'package:chaostours/view/app_widgets.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/conf/app_routes.dart';
import 'package:chaostours/model/model_alias_group.dart';
import 'package:chaostours/model/model_alias.dart';
import 'package:chaostours/util.dart';

enum _DisplayMode {
  list,
  search;
}

class WidgetAliasGroupList extends StatefulWidget {
  const WidgetAliasGroupList({super.key});

  @override
  State<WidgetAliasGroupList> createState() => _WidgetAliasGroupList();
}

class _WidgetAliasGroupList extends State<WidgetAliasGroupList> {
  // ignore: unused_field
  static final Logger logger = Logger.logger<WidgetAliasGroupList>();

  _DisplayMode _displayMode = _DisplayMode.list;
  int _selectedNavBarItem = 0;

  // height of search field container
  final double _toolBarHeight = 70;
  final TextEditingController _searchTextController = TextEditingController();

  int? _id;
  ModelAlias? _modelAlias;
  List<ModelAliasGroup>? _groups;
  List<int> _groupIds = [];
  // items per page
  static const int _limit = 30;

  final PagingController<int, ModelAliasGroup> _pagingController =
      PagingController(firstPageKey: 0);

  Future<void> loadGroups({bool reset = false}) async {
    if (_id != null && (_groups == null || reset == true)) {
      /// load model from navigator param id
      _modelAlias = await ModelAlias.byId(_id!);
      // load groups from model
      _groups = await _modelAlias?.groups() ?? [];
      // extract ids for checkboxes
      _groupIds = _groups!.map((e) => e.id).toList();
    }
  }

  Future<void> _fetchPage(int offset) async {
    try {
      await loadGroups();
      final newItems = _displayMode == _DisplayMode.list
          ? await ModelAliasGroup.select(offset: offset, limit: _limit)
          : await ModelAliasGroup.search(_searchTextController.text,
              offset: offset, limit: _limit);

      final isLastPage = newItems.length < _limit;
      if (isLastPage) {
        _pagingController.appendLastPage(newItems);
      } else {
        _pagingController.appendPage(newItems, offset + newItems.length);
      }
    } catch (error) {
      _pagingController.error = error;
    }
  }

  @override
  void dispose() {
    _pagingController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    _pagingController.addPageRequestListener(_fetchPage);
    super.initState();
  }

  void render() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    // load possible Item ID
    _id = ModalRoute.of(context)?.settings.arguments as int?;

    var body = CustomScrollView(
      slivers: <Widget>[
        /// Pinned header
        SliverPersistentHeader(
            pinned: true,
            delegate: SliverHeader(
                widget: searchWidget(), //Text('Test'),
                toolBarHeight: _toolBarHeight,
                closedHeight: 0,
                openHeight: 0)),

        /// Items List
        PagedSliverList<int, ModelAliasGroup>.separated(
          separatorBuilder: (BuildContext context, int i) => const Divider(),
          pagingController: _pagingController,
          builderDelegate: PagedChildBuilderDelegate<ModelAliasGroup>(
              itemBuilder: (context, model, index) {
            return ListTile(
              leading: edit(model),
              trailing: checkBox(model),
              title: title(model),
              subtitle: subtitle(model),
            );
          }),
        ),
      ],
    );

    return AppWidgets.scaffold(context,
        body: body,
        navBar: navBar(context),
        appBar: AppBar(title: const Text('Alias List')));
  }

  Widget title(ModelAliasGroup model) {
    return ListTile(
      title: Text(model.title),
      subtitle: Text(model.description),
    );
  }

  Widget subtitle(ModelAliasGroup model) {
    return Padding(
        padding: const EdgeInsets.only(left: 30),
        child: Text(model.description,
            style:
                TextStyle(fontSize: 12, color: Theme.of(context).hintColor)));
  }

  Widget checkBox(ModelAliasGroup model) {
    var controller = CheckboxController(
      idReference: model.id,
      referenceList: _groupIds,
      onToggle: (bool? checked) async {
        bool add = checked ?? false;
        if (add) {
          await _modelAlias?.addGroup(model);
        } else {
          await _modelAlias?.removeGroup(model);
        }
        await loadGroups(reset: true);
        _pagingController.refresh();
        render();
      },
    );
    return Checkbox(
      value: controller.checked,
      onChanged: controller.onToggle,
    );
  }

  Widget edit(ModelAliasGroup model) {
    return IconButton(
      icon: const Icon(Icons.edit),
      onPressed: () {
        Navigator.pushNamed(context, AppRoutes.editAliasGroup.route,
                arguments: model.id)
            .then(
          (value) {
            _pagingController.refresh();
            render();
          },
        );
      },
    );
  }

  Widget searchWidget() {
    return SizedBox(
        height: _toolBarHeight,
        width: Screen(context).width * 0.95,
        child: Align(
            alignment: Alignment.center,
            child: ListTile(
                trailing: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchTextController.text = "";
                    _displayMode = _DisplayMode.list;
                    _pagingController.refresh();
                    setState(() {});
                  },
                ),
                title: TextField(
                  controller: _searchTextController,
                  minLines: 1,
                  maxLines: 1,
                  decoration: const InputDecoration(
                    isDense: true,
                    //con: Icon(Icons.search, size: 30),
                    border: OutlineInputBorder(),
                    labelText: "Search",
                    contentPadding: EdgeInsets.all(10),
                  ),
                  onChanged: (value) {
                    _displayMode =
                        value.isEmpty ? _DisplayMode.list : _DisplayMode.search;
                    _pagingController.refresh();
                    setState(() {});
                  },
                ))));
  }

  BottomNavigationBar navBar(BuildContext context) {
    return BottomNavigationBar(
        currentIndex: _selectedNavBarItem,
        items: const [
          // new on osm
          BottomNavigationBarItem(
              icon: Icon(Icons.add), label: 'Create new Group'),
          // 2 nearest
          BottomNavigationBarItem(icon: Icon(Icons.near_me), label: 'Back'),
        ],
        onTap: (int id) async {
          _selectedNavBarItem = id;

          switch (id) {
            /// create
            case 0:
              var count = await ModelAliasGroup.count();
              var model = ModelAliasGroup(title: '#${count + 1}');
              model = await ModelAliasGroup.insert(model);
              if (mounted) {
                Navigator.pushNamed(context, AppRoutes.editAliasGroup.route,
                        arguments: model.id)
                    .then((_) {
                  _pagingController.refresh();
                  setState(() {});
                });
              }

              break;

            /// last visited
            case 1:
              if (mounted) {
                Navigator.pop(context);
              }
              break;

            /// default view
            default:
              setState(() {});
            //
          }
        });
  }
}
