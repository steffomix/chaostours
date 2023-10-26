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
import 'package:chaostours/logger.dart';
import 'package:flutter/material.dart';
import 'package:chaostours/chunk_loader.dart';
import 'package:chaostours/scroll_controller.dart';
import 'package:chaostours/view/app_widgets.dart';

typedef DbRow = Map<String, Object?>;

abstract class BaseWidgetPattern {
  @mustCallSuper
  void resetLoader();
  int loaderLimit() => 20;
  void initialize(BuildContext context, Object? args);
  Future<int> loadWidgets({required int offset, int limit = 20});
  Future<int?> loadCount();
  List<Widget> renderHeader(BoxConstraints constraints);
  List<Widget> renderBody(BoxConstraints constraints);
  Scaffold renderScaffold(Widget body);
}

class BaseWidget extends StatefulWidget {
  const BaseWidget({super.key});

  @override
  State<BaseWidget> createState() => BaseWidgetState();
}

class BaseWidgetState<T extends BaseWidget> extends State<T>
    implements BaseWidgetPattern {
  static final Logger logger = Logger.logger<BaseWidgetState>();
  final List<dynamic> loadedWidgets = [];
  final Loader widgetLoader = Loader();
  final ScrollContainer scrollContainer = ScrollContainer();
  ScrollContainerDirection scrollDirection = ScrollContainerDirection.both;
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

  Future<void> render({void Function()? fn}) async {
    return Future.microtask(() {
      if (mounted) {
        super.setState(fn ?? () {});
      }
    });
  }

  bool _initialized = false;
  @override
  Future<void> initialize(BuildContext context, Object? args) async {}

  @override
  Widget build(BuildContext context) {
    /// initialize
    if (!_initialized) {
      initialize(context, ModalRoute.of(context)?.settings.arguments).then((_) {
        _initialized = true;
        render();
      }).onError((e, stk) {
        logger.error('initialize: $e', stk).then(
            (value) => Navigator.pushNamed(context, AppRoutes.logger.route));
      });
      return Scaffold(body: AppWidgets.loading('Initializing...'));
    }

    /// render body
    return LayoutBuilder(
      builder: (context, constraints) {
        var header = Container(
            key: _headerKey,
            color: Theme.of(context).cardColor,
            child: Column(
                mainAxisSize: MainAxisSize.min,
                children: renderHeader(constraints)));
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
    await widgetLoader.load(
        fnLoad: loadWidgets, fnCount: loadCount, limit: loaderLimit());
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

  Widget _body(BoxConstraints constraints) {
    return scrollContainer.render(
        context: context,
        child: Column(
          children: [
            SizedBox(height: _headerHeight ?? 50, width: constraints.maxWidth),
            ...renderBody(constraints),
            !widgetLoader.finished ? AppWidgets.loading('') : AppWidgets.empty
          ],
        ),
        direction: scrollDirection);
  }

  ///
  /// implementations
  ///

  @override
  @mustCallSuper
  void resetLoader() => widgetLoader.resetLoader();

  @override
  int loaderLimit() => 20;

  @override
  Future<int> loadWidgets({required int offset, int limit = 7}) async {
    return 1;
  }

  @override
  Future<int?> loadCount() async {
    return null;
  }

  /// render widget with height of headerHeight and width of contraints.maxWidth
  @override
  List<Widget> renderHeader(BoxConstraints constraints) {
    return [const SizedBox.shrink()];
  }

  @override
  List<Widget> renderBody(BoxConstraints constraints) {
    return [const SizedBox.shrink()];
  }

  @override
  Scaffold renderScaffold(Widget body) {
    return Scaffold(body: body);
  }
}
