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
import 'package:fluttertoast/fluttertoast.dart';

import 'package:chaostours/logger.dart';
import 'package:chaostours/screen.dart';
import 'package:chaostours/conf/app_routes.dart';
import 'package:chaostours/view/app_widgets.dart';
import 'package:chaostours/model/model_User.dart';

enum _DisplayMode {
  list,
  sort;
}

class WidgetUserList extends StatefulWidget {
  const WidgetUserList({super.key});

  @override
  State<WidgetUserList> createState() => _WidgetUserList();
}

class _WidgetUserList extends State<WidgetUserList> {
  // ignore: unused_field
  static final Logger logger = Logger.logger<WidgetUserList>();

  final _showDeleted = ValueNotifier<bool>(false);
  final _textController = TextEditingController();
  _DisplayMode _displayMode = _DisplayMode.list;

  // height of seasrch field container
  final double _toolBarHeight = 70;

  // items per page
  static const int _limit = 30;

  final PagingController<int, ModelUser> _pagingController =
      PagingController(firstPageKey: 0);

  @override
  void initState() {
    _showDeleted.addListener(render);
    _pagingController.addPageRequestListener(_fetchPage);
    super.initState();
  }

  @override
  void dispose() {
    _showDeleted.dispose();
    _pagingController.dispose();
    super.dispose();
  }

  void render() {
    if (mounted) {
      setState(() {});
    }
  }

  void _fetchPage(int offset) async {
    var text = _textController.text;
    List<ModelUser> newItems = await (text.isEmpty
        ? ModelUser.select(limit: _limit, offset: offset)
        : ModelUser.search(text, limit: _limit, offset: offset));

    if (newItems.length < _limit) {
      _pagingController.appendLastPage(newItems);
    } else {
      _pagingController.appendPage(newItems, offset + newItems.length);
    }
  }

  Widget modelWidget(ModelUser model) {
    return ListBody(children: [
      ListTile(
          title: Text(model.title,
              style: TextStyle(
                  decoration: model.isActive
                      ? TextDecoration.none
                      : TextDecoration.lineThrough)),
          subtitle: Text(
            model.description,
            style: TextStyle(color: Theme.of(context).hintColor),
          ),
          trailing: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.editUser.route,
                        arguments: model.id)
                    .then((_) {
                  _pagingController.refresh();
                  render();
                });
              }))
    ]);
  }

  Widget searchWidget() {
    return SizedBox(
        height: _toolBarHeight,
        width: Screen(context).width * 0.95,
        child: Align(
            alignment: Alignment.center,
            child: TextField(
              controller: _textController,
              minLines: 1,
              maxLines: 1,
              decoration: const InputDecoration(
                  icon: Icon(Icons.search, size: 30), border: InputBorder.none),
              onChanged: (value) {
                _pagingController.refresh();
                setState(() {});
              },
            )));
  }

  Widget sortWidget(List<ModelUser> models, int index) {
    var model = models[index];
    return ListTile(
        leading: IconButton(
            icon: const Icon(Icons.arrow_downward),
            onPressed: () {
              if (index < models.length - 1) {
                models[index + 1].sortOrder--;
                model.sortOrder++;
              }
              model.update().then((_) {
                models[index + 1].update().then(
                      (value) => setState(() {}),
                    );
              });
            }),
        trailing: IconButton(
          icon: const Icon(Icons.arrow_upward),
          onPressed: () {
            if (index > 0) {
              models[index - 1].sortOrder++;
              model.sortOrder--;
            }
            model.update().then((_) {
              models[index - 1].update().then(
                    (value) => setState(() {}),
                  );
            });
          },
        ),
        title: Text(model.title,
            style: !model.isActive
                ? const TextStyle(decoration: TextDecoration.lineThrough)
                : null),
        subtitle: Text(model.description));
  }

  @override
  Widget build(BuildContext context) {
    var body = CustomScrollView(slivers: <Widget>[
      SliverPersistentHeader(
          pinned: true,
          delegate: SliverHeader(
              widget: searchWidget(), //Text('Test'),
              toolBarHeight: _toolBarHeight,
              closedHeight: 0,
              openHeight: 0)),
      PagedSliverList<int, ModelUser>.separated(
        separatorBuilder: (BuildContext context, int i) => const Divider(),
        pagingController: _pagingController,
        builderDelegate: PagedChildBuilderDelegate<ModelUser>(
          itemBuilder: (context, model, index) {
            if (_displayMode == _DisplayMode.sort) {
              if (_pagingController.itemList == null) {
                return AppWidgets.loading('Waiting for Users...');
              }
              var list = _pagingController.itemList!;
              return sortWidget(list, index);
            } else {
              return modelWidget(model);
            }
          },
        ),
      ),
    ]);

    return AppWidgets.scaffold(context,
        body: body,
        appBar: AppBar(title: const Text('Aufgaben Liste')),
        navBar: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            items: [
              const BottomNavigationBarItem(
                  icon: Icon(Icons.add), label: 'Neu'),
              _displayMode == _DisplayMode.list
                  ? const BottomNavigationBarItem(
                      icon: Icon(Icons.sort), label: 'Sortieren')
                  : const BottomNavigationBarItem(
                      icon: Icon(Icons.list), label: 'Liste'),
              BottomNavigationBarItem(
                  icon: Icon(
                      _showDeleted.value || _displayMode == _DisplayMode.sort
                          ? Icons.visibility_off
                          : Icons.visibility),
                  label: _showDeleted.value || _displayMode == _DisplayMode.sort
                      ? 'Verb. Gel.'
                      : 'Zeige Gel.')
            ],
            onTap: (int id) {
              if (id == 0) {
                ModelUser.insert(ModelUser()).then(
                  (model) {
                    Fluttertoast.showToast(msg: 'Item #${model.id} created');
                    Navigator.pushNamed(context, AppRoutes.editUser.route,
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
              if (id == 2) {
                _showDeleted.value = !_showDeleted.value;
                setState(() {});
              }
              if (id == 1) {
                _displayMode = _displayMode == _DisplayMode.list
                    ? _DisplayMode.sort
                    : _DisplayMode.list;
                setState(() {});
              }
            }));
  }
}
















/*
  TextEditingController controller = TextEditingController();
  String search = '';
  bool showDeleted = false;
  _DisplayMode displayMode = _DisplayMode.list;

  ValueNotifier<bool> modified = ValueNotifier<bool>(false);

  void modify() {
    modified.value = true;
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    Cache.reload().then((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  List<int> userIdList = DataBridge.instance.trackPointUserIdList;

  @override
  void dispose() {
    super.dispose();
  }

  Widget searchWidget(BuildContext context) {
    return Column(children: [
      TextField(
        controller: controller,
        minLines: 1,
        maxLines: 1,
        decoration: const InputDecoration(
            icon: Icon(Icons.search, size: 30), border: InputBorder.none),
        onChanged: (value) {
          search = value;
          setState(() {});
        },
      ),

      ///
      Container(child: dropdownUser(context)),
    ]);
  }

  bool dropdownUserIsOpen = false;
  Widget dropdownUser(context) {
    /// render selected users
    List<ModelUser> userModels = [];

    for (var id in userIdList) {
      var user = ModelUser.getModel(id);
      if (!user.deleted) {
        userModels.add(user);
      }
    }
    userModels.sort((a, b) => a.sortOrder - b.sortOrder);
    List<String> userList = userModels
        .map(
          (e) => e.title,
        )
        .toList();
    String users =
        userList.isNotEmpty ? '- ${userList.join('\n- ')}' : 'Keine Ausgewählt';

    /// dropdown menu botten with selected users
    List<Widget> items = [
      ElevatedButton(
        child: Column(children: [
          Center(
              child: Container(
                  padding: const EdgeInsets.all(5),
                  child: Text(
                      dropdownUserIsOpen
                          ? 'Personal vorauswählen'
                          : 'Vorausgewähltes Personal',
                      style: const TextStyle(fontSize: 16)))),
          ListTile(
              trailing: const Icon(Icons.menu),
              title: dropdownUserIsOpen ? null : Text(users),
              subtitle: !dropdownUserIsOpen
                  ? null
                  : Column(children: userCheckboxes(context))),
        ]),
        onPressed: () {
          dropdownUserIsOpen = !dropdownUserIsOpen;
          setState(() {});
        },
      ),
    ];
    return ListBody(children: items);
  }

  List<Widget> userCheckboxes(context) {
    var checkBoxes = <Widget>[];
    for (var m in ModelUser.getAll()) {
      if (!m.deleted) {
        checkBoxes.add(createCheckbox(CheckboxController(
            idReference: m.id,
            referenceList: userIdList,
            deleted: m.deleted,
            title: m.title,
            subtitle: m.notes)));
      }
    }
    return checkBoxes;
  }

  /// render multiple checkboxes
  Widget createCheckbox(CheckboxController model) {
    TextStyle style = TextStyle(
        color: model.enabled ? Colors.black : Colors.grey,
        decoration:
            model.deleted ? TextDecoration.lineThrough : TextDecoration.none);

    return ListTile(
      subtitle: model.subtitle.trim().isEmpty
          ? null
          : Text(model.subtitle, style: const TextStyle(color: Colors.grey)),
      title: Text(
        model.title,
        style: style,
      ),
      leading: Checkbox(
        value: model.checked,
        onChanged: (bool? checked) {
          if (checked ?? false) {
            userIdList.add(model.idReference);
          } else {
            userIdList.remove(model.idReference);
          }
          modify();
          setState(
            () {
              model.handler()?.call();
            },
          );
        },
      ),
      onTap: () {
        setState(
          () {
            model.handler()?.call();
          },
        );
      },
    );
  }

  Widget usersWidget(context) {
    /// search
    List<ModelUser> userlist = [];
    for (var item in ModelUser.getAll()) {
      if (!showDeleted && item.deleted) {
        continue;
      } else {
        if (showDeleted && !item.deleted) {
          continue;
        }
      }
      if (search.trim().isEmpty) {
        userlist.add(item);
      } else {
        if (item.title.contains(search) || item.notes.contains(search)) {
          userlist.add(item);
        }
      }
    }

    return ListView.builder(
        itemCount: dropdownUserIsOpen ? 1 : userlist.length + 1,
        itemBuilder: (BuildContext context, int id) {
          if (id == 0) {
            return searchWidget(context);
          } else {
            if (userlist.length == 1) {
              return AppWidgets.loading('No Items found');
            }
            ModelUser user = userlist[id - 1];
            return ListBody(children: [
              ListTile(
                  title: Text(user.title,
                      style: TextStyle(
                          decoration: user.deleted
                              ? TextDecoration.lineThrough
                              : TextDecoration.none)),
                  subtitle: Text(user.notes),
                  trailing: IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () {
                        Navigator.pushNamed(context, AppRoutes.editUser.route,
                                arguments: user.id)
                            .then((_) => setState(() {}));
                      })),
            ]);
          }
        });
  }

  Widget sortWidget(BuildContext context) {
    var list = ModelUser.getAll();
    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (context, index) {
        var model = list[index];
        return ListTile(
            leading: IconButton(
                icon: const Icon(Icons.arrow_downward),
                onPressed: () {
                  if (index < list.length - 1) {
                    list[index + 1].sortOrder--;
                    list[index].sortOrder++;
                  }
                  ModelUser.write().then((_) => setState(() {}));
                }),
            trailing: IconButton(
              icon: const Icon(Icons.arrow_upward),
              onPressed: () {
                if (index > 0) {
                  list[index - 1].sortOrder++;
                  list[index].sortOrder--;
                }
                ModelUser.write().then((_) => setState(() {}));
              },
            ),
            title: Text(model.title,
                style: model.deleted
                    ? const TextStyle(decoration: TextDecoration.lineThrough)
                    : null),
            subtitle: Text(model.notes));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppWidgets.scaffold(context,
        appBar: AppBar(title: const Text('Arbeiter Liste')),
        body: displayMode == _DisplayMode.list
            ? usersWidget(context)
            : sortWidget(context),
        navBar: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            items: [
              BottomNavigationBarItem(
                  icon: ValueListenableBuilder(
                      valueListenable: modified,
                      builder: ((context, value, child) {
                        return Icon(Icons.done,
                            size: 30,
                            color: modified.value == true
                                ? AppColors.green.color
                                : AppColors.white54.color);
                      })),
                  label: 'Speichern'),
              const BottomNavigationBarItem(
                  icon: Icon(Icons.add), label: 'Neu'),
              displayMode == _DisplayMode.list
                  ? const BottomNavigationBarItem(
                      icon: Icon(Icons.sort), label: 'Sortieren')
                  : const BottomNavigationBarItem(
                      icon: Icon(Icons.list), label: 'Liste'),
              BottomNavigationBarItem(
                  icon: Icon(showDeleted || displayMode == _DisplayMode.sort
                      ? Icons.remove_red_eye
                      : Icons.delete),
                  label: showDeleted || displayMode == _DisplayMode.sort
                      ? 'Zeige Gel.'
                      : 'Verb. Gel.'),
            ],
            onTap: (int id) {
              if (id == 0 && modified.value) {
                Cache.setValue<List<int>>(
                        CacheKeys.cacheBackgroundUserIdList, userIdList)
                    .then((_) {
                  modified.value = false;

                  dropdownUserIsOpen = false;
                  if (mounted) {
                    setState(() {});
                  }
                }).onError((e, stk) {
                  logger.error('save preselected users: $e', stk);
                });
              }
              if (id == 1) {
                Navigator.pushNamed(context, AppRoutes.editUser.route,
                        arguments: 0)
                    .then((_) => setState(() {}));
              }
              if (id == 2) {
                if (displayMode == _DisplayMode.list) {
                  displayMode = _DisplayMode.sort;
                } else {
                  displayMode = _DisplayMode.list;
                }
                setState(() {});
              }
              if (id == 3) {
                showDeleted = !showDeleted;
                setState(() {});
              }
            }));
  }
}
*/