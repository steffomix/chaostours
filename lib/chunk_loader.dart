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

class Loader {
  static final Logger logger = Logger.logger<Loader>();

  // List of loaded items
  int? _loadedTotal;
  // offset of next load and count of already loaded items
  int get offset => _loadedTotal ?? 0;

  int defaultLimit;

  //
  bool _isFinished = false;
  bool get isFinished => _isFinished;
  //
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  //
  bool _hadLoadRequest = false;
  bool get hadLoadRequest => _hadLoadRequest;

  Loader({this.defaultLimit = 20});

  Future<void> resetLoader() async {
    while (_isLoading) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    _loadedTotal = null;
    _isLoading = false;
    _hadLoadRequest = false;
    _isFinished = false;
  }

  Future<int> load(
      {required Future<int> Function({required int offset, required int limit})
          fnLoad,
      Future<int?> Function()? fnCount,
      int? limit}) async {
    logger.log('load');
    // check if finished
    if (_isFinished) {
      logger.warn('load already finished');
      return 0;
    }

    /// remember request only
    if (_isLoading) {
      _hadLoadRequest = true;
      return 0;
    }
    // start loading
    _isLoading = true;
    var countLoaded = 0;
    try {
      countLoaded = await _load(
          fnLoad: fnLoad, fnCount: fnCount, limit: limit ?? defaultLimit);
      if (_hadLoadRequest) {
        countLoaded += (await _load(
            fnLoad: fnLoad, fnCount: fnCount, limit: limit ?? defaultLimit));
      }
    } catch (e, stk) {
      logger.error('load, finish loading $e', stk);
      _hadLoadRequest = false;
      _isFinished = true;
      rethrow;
    }
    logger.log('${countLoaded}x loaded');
    _hadLoadRequest = false;
    _isLoading = false;

    //
    logger.log('$countLoaded new items loaded');
    return countLoaded;
  }

  Future<int> _load({
    required Future<int> Function({required int offset, required int limit})
        fnLoad,
    int limit = 20,
    Future<int?> Function()? fnCount,
  }) async {
    int? dbCount = await fnCount?.call();
    final countLoaded = (await fnLoad(offset: _loadedTotal ?? 0, limit: limit));
    _loadedTotal = (_loadedTotal ?? 0) + countLoaded;
    _isFinished = (dbCount == null && countLoaded < limit) ||
        (dbCount != null && _loadedTotal! >= dbCount);
    if (_isFinished) {
      logger.log('loading finished');
    }
    return countLoaded;
  }
}
