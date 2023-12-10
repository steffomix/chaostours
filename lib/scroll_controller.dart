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

enum ScrollContainerDirection {
  vertical,
  horizontal,
  both;
}

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

  Widget render(
      {required BuildContext context,
      required Widget child,
      required ScrollContainerDirection direction}) {
    switch (direction) {
      case ScrollContainerDirection.horizontal:
        return renderSingle(
            context: context, child: child, axis: Axis.horizontal);

      case ScrollContainerDirection.vertical:
        return renderSingle(
            context: context, child: child, axis: Axis.vertical);

      default:
        return renderDouble(context: context, child: child);
    }
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
