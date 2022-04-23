// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:math';
import 'package:source_maps2/parser.dart';
import 'package:test/test.dart';

void main() {
  test('encode and decode - simple values', () {
    expect(Vlq.encodeVlq(1).join(''), 'C');
    expect(Vlq.encodeVlq(2).join(''), 'E');
    expect(Vlq.encodeVlq(3).join(''), 'G');
    expect(Vlq.encodeVlq(100).join(''), 'oG');
    expect(Vlq.decodeVlq('C'.split('').iterator), 1);
    expect(Vlq.decodeVlq('E'.split('').iterator), 2);
    expect(Vlq.decodeVlq('G'.split('').iterator), 3);
    expect(Vlq.decodeVlq('oG'.split('').iterator), 100);
  });
  test('encode and decode', () {
    for (int i = -10000; i < 10000; i++) {
      _checkEncodeDecode(i);
    }
  });
  test(
    'only 32-bit ints allowed',
    () {
      final maxInt = (pow(2, 31) as int) - 1;
      final minInt = -(pow(2, 31) as int);
      _checkEncodeDecode(maxInt - 1);
      _checkEncodeDecode(minInt + 1);
      _checkEncodeDecode(maxInt);
      _checkEncodeDecode(minInt);
      expect(Vlq.encodeVlq(minInt).join(''), 'hgggggE');
      expect(Vlq.decodeVlq('hgggggE'.split('').iterator), minInt);
      expect(() => Vlq.encodeVlq(maxInt + 1), throwsA(anything));
      expect(() => Vlq.encodeVlq(maxInt + 2), throwsA(anything));
      expect(() => Vlq.encodeVlq(minInt - 1), throwsA(anything));
      expect(() => Vlq.encodeVlq(minInt - 2), throwsA(anything));
      // if we allowed more than 32 bits, these would be the expected encodings
      // for the large numbers above.
      expect(() => Vlq.decodeVlq('ggggggE'.split('').iterator), throwsA(anything));
      expect(() => Vlq.decodeVlq('igggggE'.split('').iterator), throwsA(anything));
      expect(() => Vlq.decodeVlq('jgggggE'.split('').iterator), throwsA(anything));
      expect(() => Vlq.decodeVlq('lgggggE'.split('').iterator), throwsA(anything));
    },
    // This test uses integers so large they overflow in JS.
    testOn: 'dart-vm',
  );
}

void _checkEncodeDecode(
  final int value,
) {
  final encoded = Vlq.encodeVlq(value);
  expect(Vlq.decodeVlq(encoded.iterator), value);
  expect(Vlq.decodeVlq(encoded.join('').split('').iterator), value);
}
