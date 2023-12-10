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

import 'package:chaostours/logger.dart';
import 'package:flutter/material.dart';
import 'package:chaostours/chunk_loader.dart';
import 'package:chaostours/scroll_controller.dart';
import 'package:chaostours/view/app_widgets.dart';

typedef DbRow = Map<String, Object?>;

abstract class BaseWidgetPattern {
  @mustCallSuper
  Future<void> resetLoader();
  int loaderLimit() => 20;
  void initialize(BuildContext context, Object? args);
  Future<int> loadItems({required int offset, int limit = 20});
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
  final Loader widgetLoader = Loader();
  final ScrollContainer scrollContainer = ScrollContainer();
  ScrollContainerDirection scrollDirection = ScrollContainerDirection.both;
  double? _headerHeight;
  final GlobalKey _headerKey = GlobalKey(debugLabel: 'empty header');

  @override
  @mustCallSuper
  void initState() {
    scrollContainer.onBottom = _load;
    super.initState();
  }

  Future<void> render({void Function()? fn}) async {
    Future.microtask(() {
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
      _initialized = true; // prevent double call here
      initialize(context, ModalRoute.of(context)?.settings.arguments).then((_) {
        render();
      });
      return Scaffold(body: AppWidgets.loading(const Text('Initializing...')));
    }

    /// render body
    return LayoutBuilder(
      builder: (context, constraints) {
        var header = Container(
            key: _headerKey,
            color: null, //Theme.of(context).cardColor,
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

  Future<void> _load() async {
    await widgetLoader.load(
        fnLoad: loadItems, fnCount: loadCount, limit: loaderLimit());
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
        if (!widgetLoader.isFinished) {
          _load();
        }
      }
    } catch (e) {
      logger.warn('measure body: $e');
      render();
      //Future.delayed(const Duration(milliseconds: 500), render);
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
      render();
      //Future.delayed(const Duration(milliseconds: 100), render);
    }
  }

  Widget _body(BoxConstraints constraints) {
    return scrollContainer.render(
        context: context,
        child: Column(
          children: [
            SizedBox(height: _headerHeight ?? 50, width: constraints.maxWidth),
            ...renderBody(constraints),
            !widgetLoader.isFinished
                ? AppWidgets.loading(const Text(''))
                : AppWidgets.empty
          ],
        ),
        direction: scrollDirection);
  }

  ///
  /// implementations
  ///

  @override
  @mustCallSuper
  Future<void> resetLoader() async {
    await widgetLoader.resetLoader();
  }

  @override
  int loaderLimit() => 20;

  @override
  Future<int> loadItems({required int offset, int limit = 20}) async {
    throw 'not implemented';
  }

  @override
  Future<int?> loadCount() async {
    return null;
  }

  /// render widget with height of headerHeight and width of contraints.maxWidth
  @override
  List<Widget> renderHeader(BoxConstraints constraints) {
    return const [SizedBox.shrink()];
  }

  @override
  List<Widget> renderBody(BoxConstraints constraints) {
    return const [SizedBox.shrink()];
  }

  @override
  Scaffold renderScaffold(Widget body) {
    return const Scaffold(body: Center(child: Text('Not Implementd')));
  }
}
