// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:source_maps2/builder.dart';
import 'package:source_maps2/parser.dart';
import 'package:test/test.dart';

import 'common.dart';

void main() {
  test('end-to-end setup', () {
    expect(inputVar1.text, 'longVar1');
    expect(inputFunction.text, 'longName');
    expect(inputVar2.text, 'longVar2');
    expect(inputVar1NoSymbol.text, 'longVar1');
    expect(inputFunctionNoSymbol.text, 'longName');
    expect(inputVar2NoSymbol.text, 'longVar2');
    expect(inputExpr.text, 'longVar1 + longVar2');
    expect(outputVar1.text, 'x');
    expect(outputFunction.text, 'f');
    expect(outputVar2.text, 'y');
    expect(outputVar1NoSymbol.text, 'x');
    expect(outputFunctionNoSymbol.text, 'f');
    expect(outputVar2NoSymbol.text, 'y');
    expect(outputExpr.text, 'x + y');
  });
  test('build + parse', () {
    final map = (SourceMapBuilderImpl()
          ..add_span(inputVar1, outputVar1)
          ..add_span(inputFunction, outputFunction)
          ..add_span(inputVar2, outputVar2)
          ..add_span(inputExpr, outputExpr))
        .build(output.url.toString())
        .toJson();
    final mapping = parse_sourcemap(map);
    check(outputVar1, mapping, inputVar1, false);
    check(outputVar2, mapping, inputVar2, false);
    check(outputFunction, mapping, inputFunction, false);
    check(outputExpr, mapping, inputExpr, false);
  });
  test('build + parse - no symbols', () {
    final map = (SourceMapBuilderImpl()
          ..add_span(inputVar1NoSymbol, outputVar1NoSymbol)
          ..add_span(inputFunctionNoSymbol, outputFunctionNoSymbol)
          ..add_span(inputVar2NoSymbol, outputVar2NoSymbol)
          ..add_span(inputExpr, outputExpr))
        .build(output.url.toString())
        .toJson();
    final mapping = parse_sourcemap(map);
    check(outputVar1NoSymbol, mapping, inputVar1NoSymbol, false);
    check(outputVar2NoSymbol, mapping, inputVar2NoSymbol, false);
    check(outputFunctionNoSymbol, mapping, inputFunctionNoSymbol, false);
    check(outputExpr, mapping, inputExpr, false);
  });
  test('build + parse, repeated entries', () {
    final map = (SourceMapBuilderImpl()
          ..add_span(inputVar1, outputVar1)
          ..add_span(inputVar1, outputVar1)
          ..add_span(inputFunction, outputFunction)
          ..add_span(inputFunction, outputFunction)
          ..add_span(inputVar2, outputVar2)
          ..add_span(inputVar2, outputVar2)
          ..add_span(inputExpr, outputExpr)
          ..add_span(inputExpr, outputExpr))
        .build(output.url.toString())
        .toJson();
    final mapping = parse_sourcemap(map);
    check(outputVar1, mapping, inputVar1, false);
    check(outputVar2, mapping, inputVar2, false);
    check(outputFunction, mapping, inputFunction, false);
    check(outputExpr, mapping, inputExpr, false);
  });
  test('build + parse - no symbols, repeated entries', () {
    final map = (SourceMapBuilderImpl()
          ..add_span(inputVar1NoSymbol, outputVar1NoSymbol)
          ..add_span(inputVar1NoSymbol, outputVar1NoSymbol)
          ..add_span(inputFunctionNoSymbol, outputFunctionNoSymbol)
          ..add_span(inputFunctionNoSymbol, outputFunctionNoSymbol)
          ..add_span(inputVar2NoSymbol, outputVar2NoSymbol)
          ..add_span(inputVar2NoSymbol, outputVar2NoSymbol)
          ..add_span(inputExpr, outputExpr))
        .build(output.url.toString())
        .toJson();
    final mapping = parse_sourcemap(map);
    check(outputVar1NoSymbol, mapping, inputVar1NoSymbol, false);
    check(outputVar2NoSymbol, mapping, inputVar2NoSymbol, false);
    check(outputFunctionNoSymbol, mapping, inputFunctionNoSymbol, false);
    check(outputExpr, mapping, inputExpr, false);
  });
  test('build + parse with file', () {
    final json = jsonEncode(
      (SourceMapBuilderImpl()
            ..add_span(inputVar1, outputVar1)
            ..add_span(inputFunction, outputFunction)
            ..add_span(inputVar2, outputVar2)
            ..add_span(inputExpr, outputExpr))
          .build(output.url.toString())
          .toJson(),
    );
    final mapping = parse_sourcemap(
      jsonDecode(json),
    );
    check(outputVar1, mapping, inputVar1, true);
    check(outputVar2, mapping, inputVar2, true);
    check(outputFunction, mapping, inputFunction, true);
    check(outputExpr, mapping, inputExpr, true);
  });
}
