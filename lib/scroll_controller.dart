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
import 'package:chaostours/logger.dart';

class ScrollContainer {
  GlobalKey key = GlobalKey();
  final Logger logger = Logger.logger<ScrollContainer>();
  final scrollControllerVertical = ScrollController();
  final scrollControllerHorizontal = ScrollController();
  Future<void> Function()? onTop;
  Future<void> Function()? onBottom;
  Future<void> Function()? onLeft;
  Future<void> Function()? onRight;
  Future<void> Function()? onScroll;

  // ignore: empty_constructor_bodies
  ScrollContainer(
      {this.onTop, this.onBottom, this.onLeft, this.onRight, this.onScroll}) {
    scrollControllerVertical.addListener(_verticalListener);
    scrollControllerHorizontal.addListener(_horizontalListener);
  }

  void _verticalListener() {
    onScroll?.call();
    if (scrollControllerVertical.offset >=
            scrollControllerVertical.position.maxScrollExtent &&
        !scrollControllerVertical.position.outOfRange) {
      onBottom?.call();
      logger.log("scrolled to bottom");
    }
    if (scrollControllerVertical.offset <=
            scrollControllerVertical.position.minScrollExtent &&
        !scrollControllerVertical.position.outOfRange) {
      onTop?.call();
      logger.log("scrolled to top");
    }
  }

  void _horizontalListener() {
    onScroll?.call();
    if (scrollControllerHorizontal.offset >=
            scrollControllerHorizontal.position.maxScrollExtent &&
        !scrollControllerHorizontal.position.outOfRange) {
      onLeft?.call();
      logger.log("scrolled to right");
    }
    if (scrollControllerHorizontal.offset <=
            scrollControllerHorizontal.position.minScrollExtent &&
        !scrollControllerHorizontal.position.outOfRange) {
      onRight?.call();
      logger.log("scrolled to left");
    }
  }

  void dispose() {
    scrollControllerVertical.dispose();
    scrollControllerHorizontal.dispose();
  }

  Widget renderDouble({required BuildContext context, required Widget child}) {
    return Scrollbar(
        controller: scrollControllerVertical,
        child: SingleChildScrollView(
            controller: scrollControllerVertical,
            scrollDirection: Axis.vertical,
            child: Scrollbar(
                controller: scrollControllerHorizontal,
                child: SingleChildScrollView(
                    controller: scrollControllerHorizontal,
                    scrollDirection: Axis.horizontal,
                    child: Container(key: key, child: child)))));
  }

  Widget renderSingle(
      {required BuildContext context,
      required Widget child,
      required Axis axis}) {
    var listener = axis == Axis.vertical
        ? scrollControllerVertical
        : scrollControllerHorizontal;
    return Scrollbar(
        controller: listener,
        child: SingleChildScrollView(
            controller: listener,
            scrollDirection: axis,
            child: Container(key: key, child: child)));
  }

  /// measure how much bigger the parent is than the child,
  /// so that the resulting Size may contain negative values
  Future<Size?> measure({
    Duration? delay,
    Size? parentSize,
    Size? childSize,
  }) async {
    if (delay != null) {
      await Future.delayed(delay);
    }
    if (childSize == null || parentSize == null) {
      return null;
    }
    try {
      return Size(parentSize.width - childSize.width,
          parentSize.height - childSize.height);
    } catch (e) {
      return null;
    }
  }
}

class Loader {
  static final Logger logger = Logger.logger<Loader>();

  // List of loaded items
  List<dynamic>? _loaded;
  // offset of next load and count of already loaded items
  int get offset => _loaded?.length ?? 0;
  // fixed public list of loaded items
  List<dynamic> loaded() => List.unmodifiable(_loaded ?? []);

  //
  bool _finished = false;
  bool get finished => _finished;
  //
  bool _loading = false;
  bool get loading => _loading;
  //
  bool _hadLoadRequest = false;
  bool get hadLoadRequest => _hadLoadRequest;

  Loader();

  Future<void> resetLoader() async {
    _loaded = null;
    _loading = false;
    _hadLoadRequest = false;
    _finished = false;
  }

  Future<List<dynamic>> load(
      //
      {required Future<List<dynamic>> Function(
              {required int offset, required int limit})
          fnLoad,
      int limit = 20,
      //
      Future<int> Function()? fnCount}) async {
    logger.log('load');
    // check if finished
    if (_finished) {
      logger.warn('load already finished');
      return [];
    }

    /// remember request only
    if (_loading) {
      _hadLoadRequest = true;
      return [];
    }
    // start loading
    _loading = true;
    var loaded = await _load(fnLoad: fnLoad, fnCount: fnCount, limit: limit);
    if (_hadLoadRequest) {
      loaded
          .addAll(await _load(fnLoad: fnLoad, fnCount: fnCount, limit: limit));
    }
    logger.log('${loaded.length}x loaded');
    _hadLoadRequest = false;
    _loading = false;

    //
    logger.log('${loaded.length} new items loaded');
    return loaded;
  }

  Future<List<dynamic>> _load({
    required Future<List<dynamic>> Function(
            {required int offset, required int limit})
        fnLoad,
    int limit = 20,
    Future<int> Function()? fnCount,
  }) async {
    int total = await fnCount?.call() ?? 0;
    _loaded ??= <dynamic>[];
    var loaded = await fnLoad(offset: _loaded!.length, limit: limit);
    _loaded!.addAll(loaded);
    _finished = (fnCount == null && loaded.length < limit) ||
        (fnCount != null && _loaded!.length >= total);
    logger.log('loading finished');
    return loaded;
  }
}
