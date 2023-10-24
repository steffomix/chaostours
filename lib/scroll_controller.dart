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

class ScrollEdgeController {
  final Logger logger = Logger.logger<ScrollEdgeController>();
  final scrollControllerVertical = ScrollController();
  final scrollControllerHorizontal = ScrollController();
  Future<void> Function()? onTop;
  Future<void> Function()? onBottom;
  Future<void> Function()? onLeft;
  Future<void> Function()? onRight;
  Future<void> Function()? onScroll;

  final GlobalKey key;

  // ignore: empty_constructor_bodies
  ScrollEdgeController(
      {required this.key,
      this.onTop,
      this.onBottom,
      this.onLeft,
      this.onRight,
      this.onScroll}) {
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

  Widget renderDouble(BuildContext context, Widget child) {
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
                    child: child))));
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
            controller: listener, scrollDirection: axis, child: child));
  }

  // measure height against GlobalKey widget
  Future<bool> measure(
      {required double height,
      Duration? delay,
      Future<void> Function()? onSizeIsSmaller,
      Future<void> Function()? onSizeIsSame,
      Future<void> Function()? onSizeIsBigger,
      Future<void> Function()? onSizeNotReady}) async {
    if (delay != null) {
      await Future.delayed(delay);
    }
    try {
      var size = key.currentContext?.size;
      if (size != null) {
        if (size.height < height) {
          await onSizeIsSmaller?.call();
        } else if (size.height > height) {
          await onSizeIsBigger?.call();
        } else if (size.height == height) {
          await onSizeIsSame?.call();
        }
        return true;
      } else {
        await onSizeNotReady?.call();
      }
    } catch (e) {
      await onSizeNotReady?.call();
    }
    return false;
  }
}

class Loader {
  static final Logger logger = Logger.logger<Loader>();

  // List of loaded items
  List<dynamic>? _loaded;
  // offset of next load and count of already loaded items
  int get offset => _loaded?.length ?? 0;
  // fixed public list of loaded items
  List<T> loaded<T>() => List.unmodifiable((_loaded ?? <T>[]) as List<T>);

  int limit = 20;
  //
  bool _finished = false;
  bool get finished => _finished;
  //
  bool _loading = false;
  bool get loading => _loading;
  //
  bool _hadLoadRequest = false;
  bool get hadLoadRequest => _hadLoadRequest;

  Loader({int limit = 20});

  Future<void> resetLoader() async {
    _loaded = null;
    _loading = false;
    _hadLoadRequest = false;
    _finished = false;
  }

  Future<List<T>> load<T>(
      //
      {required Future<List<T>> Function(
              {required int offset, required int limit})
          fnLoad,
      //
      Future<int> Function()? fnCount}) async {
    // check if finished
    if (_finished) {
      logger.warn('load already finished');
      return <T>[];
    }

    /// remember request only
    if (_loading) {
      _hadLoadRequest = true;
      return <T>[];
    }
    // start loading
    _loading = true;
    var loaded = await _load(load: fnLoad, count: fnCount);
    if (_hadLoadRequest) {
      loaded.addAll(await _load(load: fnLoad, count: fnCount));
    }
    _hadLoadRequest = false;
    _loading = false;
    //
    logger.log('${loaded.length} new items loaded');
    return loaded;
  }

  Future<List<T>> _load<T>({
    required Future<List<T>> Function({required int offset, required int limit})
        load,
    Future<int> Function()? count,
  }) async {
    int total = await count?.call() ?? 0;
    _loaded ??= <T>[];
    var loaded = await load(offset: _loaded!.length, limit: limit);
    _loaded!.addAll(loaded);
    _finished = (count == null && loaded.length < limit) ||
        (count != null && _loaded!.length >= total);
    logger.log('loading finished');
    return loaded;
  }
}
