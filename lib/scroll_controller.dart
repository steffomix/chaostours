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
import 'package:chaostours/screen.dart';

typedef SingleScrollListener = void Function(ScrollController ctrl);
typedef DoubleScrollListener = void Function(
    {required ScrollController vertical, required ScrollController horizontal});

class ScrollEdgeController {
  final Logger logger = Logger.logger<ScrollEdgeController>();
  final _vertical = ScrollController();
  final _horizontal = ScrollController();
  SingleScrollListener? onTop;
  SingleScrollListener? onBottom;
  SingleScrollListener? onLeft;
  SingleScrollListener? onRight;
  DoubleScrollListener? onScroll;

  // ignore: empty_constructor_bodies
  ScrollEdgeController(
      {this.onTop, this.onBottom, this.onLeft, this.onRight, this.onScroll}) {
    _vertical.addListener(_verticalListener);
    _horizontal.addListener(_horizontalListener);
  }

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

  void dispose() {
    _vertical.dispose();
    _horizontal.dispose();
  }

  Widget renderDouble(BuildContext context, Widget child) {
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

  Widget renderSingle(BuildContext context, Widget child, Axis axis) {
    var listener = axis == Axis.vertical ? _vertical : _horizontal;
    return Scrollbar(
        controller: listener,
        child: SingleChildScrollView(
            controller: listener, scrollDirection: axis, child: child));
  }
}

class Loader {
  static final Logger logger = Logger.logger<Loader>();
  final GlobalKey key;

  Loader({required this.key});

  Future<void> checkSize(
      {required Screen screen,
      Future<void> Function()? onSizeIsSmaller,
      Future<void> Function()? onSizeIsSame,
      Future<void> Function()? onSizeIsBigger,
      Future<void> Function()? onSizeNotReady}) async {
    var size = key.currentContext?.size;
    if (size != null) {
      if (size.height < screen.height) {
        await onSizeIsSmaller?.call();
      } else if (size.height > screen.height) {
        await onSizeIsBigger?.call();
      } else if (size.height == screen.height) {
        await onSizeIsSame?.call();
      }
    } else {
      await onSizeNotReady?.call();
    }
  }

  List<dynamic>? _loaded;
  int? _total;

  int get countLoaded => _loaded?.length ?? 0;
  bool _loading = false;
  bool _hadLoadRequest = false;
  bool _finished = false;

  Future<void> resetLoader() async {
    _loaded = null;
    _total = null;
    _loading = false;
    _hadLoadRequest = false;
    _finished = false;
  }

  List<T> getLoaded<T>() {
    return List.unmodifiable((_loaded ?? <T>[]) as List<T>);
  }

  Future<List<T>> loadNext<T>(
      {required Future<List<T>> Function(
              {required int offset, required int limit})
          load,
      Future<int> Function()? count,
      required int limit}) async {
    logger.log('loadNext, $countLoaded loaded');
    if (_finished ||
        (_total != null && _loaded != null && _total! <= _loaded!.length)) {
      return <T>[];
    }

    /// remember request
    if (_loading) {
      _hadLoadRequest = true;
      return <T>[];
    }
    _loading = true;
    var loaded = await _load(load: load, count: count, limit: limit);
    if (_hadLoadRequest) {
      loaded.addAll(await _load(load: load, count: count, limit: limit));
    }
    _hadLoadRequest = false;
    _loading = false;
    logger.log('loadNext finished, $countLoaded loaded');
    return loaded;
  }

  Future<List<T>> _load<T>(
      {required Future<List<T>> Function(
              {required int offset, required int limit})
          load,
      Future<int> Function()? count,
      required int limit}) async {
    logger.log('_load, , $countLoaded loaded');
    _total = await count?.call();
    _loaded ??= <T>[];
    var loaded = await load(offset: _loaded!.length, limit: limit);
    _loaded!.addAll(loaded);
    _finished = count == null && loaded.length < limit;

    logger.log('_load finished, $countLoaded loaded');
    return loaded;
  }
}
