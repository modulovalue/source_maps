// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Tests for the binary search utility algorithm.

import 'package:source_maps2/parser.dart';
import 'package:test/test.dart';

void main() {
  group('binary search', () {
    test('empty', () {
      expect(binarySearch(<int>[])((final x) => true), -1);
    });
    test('single element', () {
      expect(binarySearch([1])((final x) => true), 0);
      expect(binarySearch([1])((final x) => false), 1);
    });
    test('no matches', () {
      final list = [1, 2, 3, 4, 5, 6, 7];
      expect(binarySearch(list)((final x) => false), list.length);
    });
    test('all match', () {
      final list = [1, 2, 3, 4, 5, 6, 7];
      expect(binarySearch(list)((final x) => true), 0);
    });
    test('compare with linear search', () {
      for (var size = 0; size < 100; size++) {
        final list = <int>[];
        for (var i = 0; i < size; i++) {
          list.add(i);
        }
        for (var pos = 0; pos <= size; pos++) {
          expect(binarySearch<int>(list)((final x) => x >= pos), _linearSearch(list)((final x) => x >= pos));
        }
      }
    });
  });
}

int Function(
  bool Function(T),
) _linearSearch<T>(
  final List<T> list,
) =>
    (final predicate) {
      if (list.isEmpty) {
        return -1;
      } else {
        for (var i = 0; i < list.length; i++) {
          if (predicate(list[i])) {
            return i;
          }
        }
        return list.length;
      }
    };
