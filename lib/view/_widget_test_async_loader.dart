import 'package:chaostours/screen.dart';
import 'package:chaostours/view/app_widgets.dart';
import 'package:flutter/material.dart';
import 'package:chaostours/scroll_controller.dart';

class BaseWidget extends StatefulWidget {
  const BaseWidget({super.key});

  @override
  State<BaseWidget> createState() => BaseWidgetState();
}

class BaseWidgetState<T extends BaseWidget> extends State<T> {
  final List<Widget> _items = [];
  final Loader _loader = Loader(limit: 10);
  final ScrollEdgeController _scroller =
      ScrollEdgeController(key: GlobalKey(debugLabel: 'mainBody'));

  final double _headerHeight = 50;

  @override
  void initState() {
    _items.clear();
    for (var i = 0; i < 200; i++) {
      _items
          .add(Align(alignment: Alignment.centerLeft, child: Text('Item $i')));
    }

    super.initState();
    load();
    _scroller.onBottom = load;
  }

  void render() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> load() async {
    _loader.load<Widget>(fnLoad: _load).then(
          (value) => render(),
        );
  }

  Future<List<Widget>> _load({required int offset, int limit = 50}) async {
    var newItems = await Future.delayed(const Duration(milliseconds: 500), () {
      List<Widget> list = [];
      try {
        var sublist = _items.getRange(offset, offset + limit).toList();
        list.addAll(sublist);
      } catch (e) {
        print(e);
      }
      return list;
    });

    /// render Items
    // ...
    /// return result
    return newItems;
  }

  Widget header({Widget? widget}) {
    final width = Screen(context).width;
    return SizedBox(
        width: width,
        height: _headerHeight,
        child: Container(color: Colors.green, child: Text('header')));
  }

  Widget body() {
    return _scroller.renderSingle(
        context: context,
        child: Column(
          key: _scroller.key,
          children: [header(), ..._loader.loaded<Widget>()],
        ),
        axis: Axis.vertical);
  }

  @override
  Widget build(BuildContext context) {
    _scroller.measure(
        height: Screen(context).height,
        delay: Duration(milliseconds: 200),
        onSizeIsSmaller: load);
    return AppWidgets.scaffold(context,
        body: Stack(alignment: Alignment.topLeft, children: [
          body(),
          header(),
        ]));
  }
}
