// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:source_maps2/builder.dart';
import 'package:test/test.dart';

import 'common.dart';

void main() {
  test('builder - with span', () {
    final map = (SourceMapBuilderImpl()
          ..add_span(inputVar1, outputVar1)
          ..add_span(inputFunction, outputFunction)
          ..add_span(inputVar2, outputVar2)
          ..add_span(inputExpr, outputExpr))
        .build(output.url.toString())
        .toJson();
    expect(
      map,
      equals(expectedMap),
    );
  });
  test('builder - with location', () {
    final str = jsonEncode(
      (SourceMapBuilderImpl()
            ..add_location(inputVar1.start, outputVar1.start, 'longVar1')
            ..add_location(inputFunction.start, outputFunction.start, 'longName')
            ..add_location(inputVar2.start, outputVar2.start, 'longVar2')
            ..add_location(inputExpr.start, outputExpr.start, null))
          .build(output.url.toString())
          .toJson(),
    );
    expect(
      str,
      jsonEncode(expectedMap),
    );
  });
}
