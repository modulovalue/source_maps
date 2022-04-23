// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:source_maps2/parser.dart';
import 'package:source_maps2/source_map_span.dart';
// TODO remove this dependency.
import 'package:source_span/source_span.dart';
import 'package:test/test.dart';

/// Content of the source file
const String inputContent = '''
/** this is a comment. */
int longVar1 = 3;

// this is a comment too
int longName(int longVar2) {
  return longVar1 + longVar2;
}
''';
final input = SourceFile.fromString(
  inputContent,
  url: 'input.dart',
);

/// A span in the input file.
SourcemapSpan _ispan(
  final int start,
  final int end, [
  final bool isIdentifier = false,
]) {
  final span = input.span(
    start,
    end,
  );
  return SourcemapSpanImpl(
    span.start,
    span.end,
    span.text,
    isIdentifier,
  );
}

final SourcemapSpan inputVar1 = _ispan(30, 38, true);
final SourcemapSpan inputFunction = _ispan(74, 82, true);
final SourcemapSpan inputVar2 = _ispan(87, 95, true);
final SourcemapSpan inputVar1NoSymbol = _ispan(30, 38);
final SourcemapSpan inputFunctionNoSymbol = _ispan(74, 82);
final SourcemapSpan inputVar2NoSymbol = _ispan(87, 95);
final SourcemapSpan inputExpr = _ispan(108, 127);

/// Content of the target file
const String outputContent = '''
var x = 3;
f(y) => x + y;
''';
final output = SourceFile.fromString(outputContent, url: 'output.dart');

/// A span in the output file
SourcemapSpan _ospan(
  final int start,
  final int end, [
  final bool isIdentifier = false,
]) {
  final span = output.span(
    start,
    end,
  );
  return SourcemapSpanImpl(
    span.start,
    span.end,
    span.text,
    isIdentifier,
  );
}

final SourcemapSpan outputVar1 = _ospan(4, 5, true);
final SourcemapSpan outputFunction = _ospan(11, 12, true);
final SourcemapSpan outputVar2 = _ospan(13, 14, true);
final SourcemapSpan outputVar1NoSymbol = _ospan(4, 5);
final SourcemapSpan outputFunctionNoSymbol = _ospan(11, 12);
final SourcemapSpan outputVar2NoSymbol = _ospan(13, 14);
final SourcemapSpan outputExpr = _ospan(19, 24);

/// Expected output mapping when recording the following four mappings:
///      inputVar1       <=   outputVar1
///      inputFunction   <=   outputFunction
///      inputVar2       <=   outputVar2
///      inputExpr       <=   outputExpr
///
/// This mapping is stored in the tests so we can independently test the builder
/// and parser algorithms without relying entirely on end2end tests.
const Map<String, dynamic> expectedMap = <String, dynamic>{
  'version': 3,
  'sourceRoot': '',
  'sources': ['input.dart'],
  'names': ['longVar1', 'longName', 'longVar2'],
  'mappings': 'IACIA;AAGAC,EAAaC,MACR',
  'file': 'output.dart'
};

void check(
  final SourcemapSpan outputSpan,
  final Sourcemap mapping,
  final SourcemapSpan inputSpan,
  final bool realOffsets,
) {
  final line = outputSpan.start.line;
  final column = outputSpan.start.column;
  final files = () {
    if (realOffsets) {
      return {'input.dart': input};
    } else {
      return null;
    }
  }();
  final span = mapping.span_for(line, column, files: files)!;
  final span2 = mapping.span_for_location(outputSpan.start, files: files)!;
  // Both mapping APIs are equivalent.
  expect(span.start.offset, span2.start.offset);
  expect(span.start.line, span2.start.line);
  expect(span.start.column, span2.start.column);
  expect(span.end.offset, span2.end.offset);
  expect(span.end.line, span2.end.line);
  expect(span.end.column, span2.end.column);
  // Mapping matches our input location (modulo using real offsets)
  expect(span.start.line, inputSpan.start.line);
  expect(span.start.column, inputSpan.start.column);
  expect(span.sourceUrl, inputSpan.sourceUrl);
  expect(span.start.offset, realOffsets ? inputSpan.start.offset : 0);
  // Mapping includes the identifier, if any
  if (inputSpan.is_identifier) {
    expect(span.end.line, inputSpan.end.line);
    expect(span.end.column, inputSpan.end.column);
    expect(span.end.offset, span.start.offset + inputSpan.text.length);
    if (realOffsets) {
      expect(span.end.offset, inputSpan.end.offset);
    }
  } else {
    expect(span.end.offset, span.start.offset);
    expect(span.end.line, span.start.line);
    expect(span.end.column, span.start.column);
  }
}
