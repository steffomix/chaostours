import 'package:chaostours/database.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/view/app_widgets.dart';
import 'package:flutter/material.dart';
import 'package:chaostours/scroll_controller.dart';
import 'package:chaostours/model/model.dart';

typedef ModelRow = Map<String, Object?>;

class HomeWidget extends BaseWidget {
  const HomeWidget({Key? key}) : super(key: key);
  @override
  State<HomeWidget> createState() => _HomeWidget();
}

class _HomeWidget extends BaseWidgetState<HomeWidget> {
  TableFields _table = TableFields.tables[0];

  final _searchController = TextEditingController();

  @override
  int limit() => 5;

  double headerHight = 100;

  final List<DataRow> loadedItems = [];

  @override
  Future<List<dynamic>> loadWidgets(
      {required int offset, int limit = 5}) async {
    final rows = [];
    final search = _searchController.text;

    rows.addAll(await Model.select(_table,
        limit: limit, offset: offset, search: search));
    loadedItems.addAll(rows.map(
      (e) => renderRow(e),
    ));
    return rows;
  }

  @override
  void reset() {
    loadedItems.clear();
    super.reset();
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
  Widget renderHeader({required BoxConstraints constraints, Widget? widget}) {
    return Wrap(
      children: [
        Column(children: [
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
                      reset();
                      render();
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
                  reset();
                },
              ),
              title: TextField(
                controller: _searchController,
                onChanged: (value) {
                  reset();
                  render();
                },
              )),
        ])
      ],
    );
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
  List<Widget> body(BoxConstraints constraints) {
    var tb = DataTable(
        //dataRowMinHeight: 200,
        //dataRowMaxHeight: 400,
        columns: renderTableHeader(),
        rows: loadedItems);
    return <Widget>[tb];
  }

  @override
  Scaffold renderScaffold(Widget body) {
    return AppWidgets.scaffold(context, body: body);
  }
}

///
///
///
///
///
///
///

abstract class BaseWidgetPattern {
  double headerHeight = 20;
  Future<List<dynamic>> loadWidgets({required int offset, int limit = 4});
  Widget renderHeader({Widget? widget, required BoxConstraints constraints});
  Scaffold renderScaffold(Widget body);
}

class BaseWidget extends StatefulWidget {
  const BaseWidget({super.key});

  @override
  State<BaseWidget> createState() => BaseWidgetState();
}

class BaseWidgetState<T extends BaseWidget> extends State<T> {
  static final Logger logger = Logger.logger<BaseWidgetState>();
  final List<dynamic> loadedWidgets = [];
  final Loader widgetLoader = Loader();
  final ScrollContainer scrollContainer = ScrollContainer();
  int limit() => throw 'not implemented';
  double? _headerHeight;
  final GlobalKey _headerKey = GlobalKey(debugLabel: 'empty header');

  @override
  @mustCallSuper
  void initState() {
    loadedWidgets.clear();
    for (var i = 0; i < 200; i++) {
      loadedWidgets
          .add(Align(alignment: Alignment.centerLeft, child: Text('Item $i')));
    }

    super.initState();
    //_load();
    scrollContainer.onBottom = load;
  }

  @mustCallSuper
  void reset() => widgetLoader.resetLoader();

  Future<void> render({void Function()? fn}) async {
    return Future.microtask(() {
      if (mounted) {
        super.setState(fn ?? () {});
      }
    });
  }

  Future<List<dynamic>> loadWidgets(
      {required int offset, int limit = 7}) async {
    throw 'not implemented';
  }

  /// render widget with height of headerHeight and width of contraints.maxWidth
  Widget renderHeader({Widget? widget, required BoxConstraints constraints}) {
    throw 'not implemented';
    /*
    return SizedBox(
        width: constraints.maxWidth,
        height: headerHeight,
        child: widget ?? const SizedBox.shrink());
        */
  }

  Scaffold renderScaffold(Widget body) {
    throw 'not implemented';
    /*
    return AppWidgets.scaffold(context, body: body);
    */
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        var header = Container(
            color: const Color.fromARGB(65, 0, 0, 0),
            key: _headerKey,
            child: renderHeader(constraints: constraints));
        var body = _body(constraints);
        var scaffold =
            renderScaffold(Stack(alignment: Alignment.topLeft, children: [
          body,
          header,
        ]));
        Future.microtask(() => _measureBody(constraints));
        Future.microtask(() => _measureHeader());
        return scaffold;
      },
    );
  }

  Future<void> load() async {
    await widgetLoader.load(fnLoad: loadWidgets, limit: limit());
    render();
  }

  Future<void> _measureBody(BoxConstraints constrains) async {
    try {
      var pSize = Size(constrains.maxWidth, constrains.maxHeight);
      var cSize = scrollContainer.key.currentContext?.size;

      final size = cSize == null
          ? null
          : Size(pSize.width - cSize.width, pSize.height - cSize.height);

      if ((size?.height ?? 0) > 0) {
        if (!widgetLoader.finished) {
          load();
        }
      }
    } catch (e) {
      logger.warn('measure body: $e');
      Future.delayed(const Duration(milliseconds: 500), render);
    }
  }

  Future<void> _measureHeader() async {
    try {
      final size = _headerKey.currentContext?.size;
      bool init = _headerHeight == null;
      if (size == null) {
        throw '';
      } else {
        _headerHeight = size.height;
        if (init) {
          render();
        }
      }
    } catch (e) {
      logger.warn('measure header: $e');
      Future.delayed(const Duration(milliseconds: 100), render);
    }
  }

  List<Widget> body(BoxConstraints constraints) {
    throw 'not implemented';
    //return widgetLoader.loaded() as List<Widget>;
  }

  Widget _body(BoxConstraints constraints) {
    return scrollContainer.renderDouble(
        context: context,
        child: Column(
          children: [
            SizedBox(height: _headerHeight ?? 50, width: constraints.maxWidth),
            ...body(constraints),
            !widgetLoader.finished ? AppWidgets.loading('') : AppWidgets.empty
          ],
        ));
  }
}
