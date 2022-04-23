// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:source_maps2/builder.dart';
import 'package:source_maps2/parser.dart';
// TODO remove this dependency.
import 'package:source_span/source_span.dart';
import 'package:test/test.dart';

import 'common.dart';

const Map<String, dynamic> _mapWithNoSourceLocation = <String, dynamic>{
  'version': 3,
  'sourceRoot': '',
  'sources': ['input.dart'],
  'names': <String>[],
  'mappings': 'A',
  'file': 'output.dart'
};

const Map<String, dynamic> _mapWithSourceLocation = <String, dynamic>{
  'version': 3,
  'sourceRoot': '',
  'sources': ['input.dart'],
  'names': <String>[],
  'mappings': 'AAAA',
  'file': 'output.dart'
};

const Map<String, dynamic> _mapWithSourceLocationAndMissingNames = <String, dynamic>{
  'version': 3,
  'sourceRoot': '',
  'sources': ['input.dart'],
  'mappings': 'AAAA',
  'file': 'output.dart'
};

const Map<String, dynamic> _mapWithSourceLocationAndName = <String, dynamic>{
  'version': 3,
  'sourceRoot': '',
  'sources': ['input.dart'],
  'names': ['var'],
  'mappings': 'AAAAA',
  'file': 'output.dart'
};

const Map<String, dynamic> _mapWithSourceLocationAndName1 = <String, dynamic>{
  'version': 3,
  'sourceRoot': 'pkg/',
  'sources': ['input1.dart'],
  'names': ['var1'],
  'mappings': 'AAAAA',
  'file': 'output.dart'
};

const Map<String, dynamic> _mapWithSourceLocationAndName2 = <String, dynamic>{
  'version': 3,
  'sourceRoot': 'pkg/',
  'sources': ['input2.dart'],
  'names': ['var2'],
  'mappings': 'AAAAA',
  'file': 'output2.dart'
};

const Map<String, dynamic> _mapWithSourceLocationAndName3 = <String, dynamic>{
  'version': 3,
  'sourceRoot': 'pkg/',
  'sources': ['input3.dart'],
  'names': ['var3'],
  'mappings': 'AAAAA',
  'file': '3/output.dart'
};

const _sourceMapBundle = [
  _mapWithSourceLocationAndName1,
  _mapWithSourceLocationAndName2,
  _mapWithSourceLocationAndName3,
];

void main() {
  test('parse', () {
    final mapping = parse_sourcemap(expectedMap);
    check(outputVar1, mapping, inputVar1, false);
    check(outputVar2, mapping, inputVar2, false);
    check(outputFunction, mapping, inputFunction, false);
    check(outputExpr, mapping, inputExpr, false);
  });
  test('parse + json', () {
    final mapping = parse_sourcemap(jsonDecode(jsonEncode(expectedMap)));
    check(outputVar1, mapping, inputVar1, false);
    check(outputVar2, mapping, inputVar2, false);
    check(outputFunction, mapping, inputFunction, false);
    check(outputExpr, mapping, inputExpr, false);
  });
  test('parse with file', () {
    final mapping = parse_sourcemap(expectedMap);
    check(outputVar1, mapping, inputVar1, true);
    check(outputVar2, mapping, inputVar2, true);
    check(outputFunction, mapping, inputFunction, true);
    check(outputExpr, mapping, inputExpr, true);
  });
  test('parse with no source location', () {
    final map = parse_sourcemap(jsonDecode(jsonEncode(_mapWithNoSourceLocation))) as SourcemapSingle;
    expect(map.lines.length, 1);
    expect(map.lines.first.entries.length, 1);
    final entry = map.lines.first.entries.first;
    expect(entry.column, 0);
    expect(entry.sourceUrlId, null);
    expect(entry.sourceColumn, null);
    expect(entry.sourceLine, null);
    expect(entry.sourceNameId, null);
  });
  test('parse with source location and no name', () {
    final map = parse_sourcemap(jsonDecode(jsonEncode(_mapWithSourceLocation))) as SourcemapSingle;
    expect(map.lines.length, 1);
    expect(map.lines.first.entries.length, 1);
    final entry = map.lines.first.entries.first;
    expect(entry.column, 0);
    expect(entry.sourceUrlId, 0);
    expect(entry.sourceColumn, 0);
    expect(entry.sourceLine, 0);
    expect(entry.sourceNameId, null);
  });
  test('parse with source location and missing names entry', () {
    final map =
        parse_sourcemap(jsonDecode(jsonEncode(_mapWithSourceLocationAndMissingNames))) as SourcemapSingle;
    expect(map.lines.length, 1);
    expect(map.lines.first.entries.length, 1);
    final entry = map.lines.first.entries.first;
    expect(entry.column, 0);
    expect(entry.sourceUrlId, 0);
    expect(entry.sourceColumn, 0);
    expect(entry.sourceLine, 0);
    expect(entry.sourceNameId, null);
  });
  test('parse with source location and name', () {
    final map = parse_sourcemap(jsonDecode(jsonEncode(_mapWithSourceLocationAndName))) as SourcemapSingle;
    expect(map.lines.length, 1);
    expect(map.lines.first.entries.length, 1);
    final entry = map.lines.first.entries.first;
    expect(entry.sourceUrlId, 0);
    expect(entry.sourceUrlId, 0);
    expect(entry.sourceColumn, 0);
    expect(entry.sourceLine, 0);
    expect(entry.sourceNameId, 0);
  });
  test('parse with source root', () {
    final inputMap = Map<String, dynamic>.from(_mapWithSourceLocation);
    inputMap['sourceRoot'] = '/pkg/';
    final mapping = parse_sourcemap(inputMap) as SourcemapSingle;
    expect(mapping.span_for(0, 0)?.sourceUrl, Uri.parse('/pkg/input.dart'));
    expect(mapping.span_for_location(SourceLocation(0, sourceUrl: Uri.parse('ignored.dart')))?.sourceUrl,
        Uri.parse('/pkg/input.dart'));
    const newSourceRoot = '/new/';
    mapping.source_root = newSourceRoot;
    inputMap['sourceRoot'] = newSourceRoot;
    expect(mapping.toJson(), equals(inputMap));
  });
  test('parse with map URL', () {
    final inputMap = Map<String, dynamic>.from(_mapWithSourceLocation);
    inputMap['sourceRoot'] = 'pkg/';
    final mapping = parse_sourcemap(inputMap, mapUrl: Uri.tryParse('file:///path/to/map'));
    expect(mapping.span_for(0, 0)?.sourceUrl, Uri.parse('file:///path/to/pkg/input.dart'));
  });
  group('parse with bundle', () {
    final mapping = parse_sourcemap(_sourceMapBundle, mapUrl: Uri.tryParse('file:///path/to/map'));
    test('simple', () {
      expect(
          mapping
              .span_for_location(SourceLocation(0, sourceUrl: Uri.file('/path/to/output.dart')))
              ?.sourceUrl,
          Uri.parse('file:///path/to/pkg/input1.dart'));
      expect(
          mapping
              .span_for_location(SourceLocation(0, sourceUrl: Uri.file('/path/to/output2.dart')))
              ?.sourceUrl,
          Uri.parse('file:///path/to/pkg/input2.dart'));
      expect(
          mapping
              .span_for_location(SourceLocation(0, sourceUrl: Uri.file('/path/to/3/output.dart')))
              ?.sourceUrl,
          Uri.parse('file:///path/to/pkg/input3.dart'));
      expect(mapping.span_for(0, 0, uri: 'file:///path/to/output.dart')?.sourceUrl,
          Uri.parse('file:///path/to/pkg/input1.dart'));
      expect(mapping.span_for(0, 0, uri: 'file:///path/to/output2.dart')?.sourceUrl,
          Uri.parse('file:///path/to/pkg/input2.dart'));
      expect(mapping.span_for(0, 0, uri: 'file:///path/to/3/output.dart')?.sourceUrl,
          Uri.parse('file:///path/to/pkg/input3.dart'));
    });
    test('package uris', () {
      expect(
          mapping
              .span_for_location(SourceLocation(0, sourceUrl: Uri.parse('package:1/output.dart')))
              ?.sourceUrl,
          Uri.parse('file:///path/to/pkg/input1.dart'));
      expect(
          mapping
              .span_for_location(SourceLocation(0, sourceUrl: Uri.parse('package:2/output2.dart')))
              ?.sourceUrl,
          Uri.parse('file:///path/to/pkg/input2.dart'));
      expect(
          mapping
              .span_for_location(SourceLocation(0, sourceUrl: Uri.parse('package:3/output.dart')))
              ?.sourceUrl,
          Uri.parse('file:///path/to/pkg/input3.dart'));
      expect(mapping.span_for(0, 0, uri: 'package:1/output.dart')?.sourceUrl,
          Uri.parse('file:///path/to/pkg/input1.dart'));
      expect(mapping.span_for(0, 0, uri: 'package:2/output2.dart')?.sourceUrl,
          Uri.parse('file:///path/to/pkg/input2.dart'));
      expect(mapping.span_for(0, 0, uri: 'package:3/output.dart')?.sourceUrl,
          Uri.parse('file:///path/to/pkg/input3.dart'));
    });
    test('unmapped path', () {
      var span = mapping.span_for(0, 0, uri: 'unmapped_output.dart')!;
      expect(span.sourceUrl, Uri.parse('unmapped_output.dart'));
      expect(span.start.line, equals(0));
      expect(span.start.column, equals(0));
      span = mapping.span_for(10, 5, uri: 'unmapped_output.dart')!;
      expect(span.sourceUrl, Uri.parse('unmapped_output.dart'));
      expect(span.start.line, equals(10));
      expect(span.start.column, equals(5));
    });
    test('missing path', () {
      expect(() => mapping.span_for(0, 0), throwsA(anything));
    });
    test('incomplete paths', () {
      expect(mapping.span_for(0, 0, uri: 'output.dart')?.sourceUrl,
          Uri.parse('file:///path/to/pkg/input1.dart'));
      expect(mapping.span_for(0, 0, uri: 'output2.dart')?.sourceUrl,
          Uri.parse('file:///path/to/pkg/input2.dart'));
      expect(mapping.span_for(0, 0, uri: '3/output.dart')?.sourceUrl,
          Uri.parse('file:///path/to/pkg/input3.dart'));
    });
    test('parseExtended', () {
      final mapping = parse_sourcemap(_sourceMapBundle, mapUrl: Uri.tryParse('file:///path/to/map'));
      expect(mapping.span_for(0, 0, uri: 'output.dart')?.sourceUrl,
          Uri.parse('file:///path/to/pkg/input1.dart'));
      expect(mapping.span_for(0, 0, uri: 'output2.dart')?.sourceUrl,
          Uri.parse('file:///path/to/pkg/input2.dart'));
      expect(mapping.span_for(0, 0, uri: '3/output.dart')?.sourceUrl,
          Uri.parse('file:///path/to/pkg/input3.dart'));
    });
    test('build bundle incrementally', () {
      final mapping = SourcemapBundle();
      mapping.addMapping(
          parse_sourcemap(_mapWithSourceLocationAndName1, mapUrl: Uri.tryParse('file:///path/to/map'))
              as SourcemapSingle);
      expect(
        mapping.span_for(0, 0, uri: 'output.dart')?.sourceUrl,
        Uri.parse('file:///path/to/pkg/input1.dart'),
      );
      expect(mapping.containsMapping('output2.dart'), isFalse);
      mapping.addMapping(
        parse_sourcemap(_mapWithSourceLocationAndName2, mapUrl: Uri.tryParse('file:///path/to/map'))
            as SourcemapSingle,
      );
      expect(mapping.containsMapping('output2.dart'), isTrue);
      expect(
        mapping.span_for(0, 0, uri: 'output2.dart')?.sourceUrl,
        Uri.parse('file:///path/to/pkg/input2.dart'),
      );
      expect(mapping.containsMapping('3/output.dart'), isFalse);
      mapping.addMapping(
        parse_sourcemap(
          _mapWithSourceLocationAndName3,
          mapUrl: Uri.tryParse('file:///path/to/map'),
        ) as SourcemapSingle,
      );
      expect(mapping.containsMapping('3/output.dart'), isTrue);
      expect(
        mapping.span_for(0, 0, uri: '3/output.dart')?.sourceUrl,
        Uri.parse('file:///path/to/pkg/input3.dart'),
      );
    });
    // Test that the source map can handle cases where the uri passed in is
    // not from the expected host but it is still unambiguous which source
    // map should be used.
    test('different paths', () {
      expect(
        mapping
            .span_for_location(
              SourceLocation(
                0,
                sourceUrl: Uri.parse('http://localhost/output.dart'),
              ),
            )
            ?.sourceUrl,
        Uri.parse('file:///path/to/pkg/input1.dart'),
      );
      expect(
        mapping
            .span_for_location(
              SourceLocation(
                0,
                sourceUrl: Uri.parse('http://localhost/output2.dart'),
              ),
            )
            ?.sourceUrl,
        Uri.parse('file:///path/to/pkg/input2.dart'),
      );
      expect(
        mapping
            .span_for_location(
              SourceLocation(
                0,
                sourceUrl: Uri.parse('http://localhost/3/output.dart'),
              ),
            )
            ?.sourceUrl,
        Uri.parse('file:///path/to/pkg/input3.dart'),
      );
      expect(mapping.span_for(0, 0, uri: 'http://localhost/output.dart')?.sourceUrl,
          Uri.parse('file:///path/to/pkg/input1.dart'));
      expect(mapping.span_for(0, 0, uri: 'http://localhost/output2.dart')?.sourceUrl,
          Uri.parse('file:///path/to/pkg/input2.dart'));
      expect(mapping.span_for(0, 0, uri: 'http://localhost/3/output.dart')?.sourceUrl,
          Uri.parse('file:///path/to/pkg/input3.dart'));
    });
  });
  test('parse and re-emit', () {
    for (final expected in [
      expectedMap,
      _mapWithNoSourceLocation,
      _mapWithSourceLocation,
      _mapWithSourceLocationAndName
    ]) {
      SourcemapSingle mapping = parse_sourcemap(expected) as SourcemapSingle;
      expect(mapping.toJson(), equals(expected));
      mapping = parse_sourcemap(expected) as SourcemapSingle;
      expect(mapping.toJson(), equals(expected));
    }
    final mapping = parse_sourcemap(_sourceMapBundle) as SourcemapBundle;
    expect(mapping.toJson(), equals(_sourceMapBundle));
  });
  test('parse extensions', () {
    final map = Map<String, dynamic>.from(expectedMap);
    map['x_foo'] = 'a';
    map['x_bar'] = [3];
    final mapping = parse_sourcemap(map) as SourcemapSingle;
    expect(mapping.toJson(), equals(map));
    expect(mapping.extensions['x_foo'], equals('a'));
    expect((mapping.extensions['x_bar'] as List).first, equals(3));
  });
  group('source files', () {
    group('from fromEntries()', () {
      test('are null for non-FileLocations', () {
        final mapping = SourcemapSingle.from_entries(
          [
            EntryImpl(
              source: SourceLocation(10, line: 1, column: 8),
              target: outputVar1.start,
              identifier_name: null,
            ),
          ],
        );
        expect(mapping.files, equals([null]));
      });
      test("use a file location's file", () {
        final mapping = SourcemapSingle.from_entries(
          [
            EntryImpl(
              source: inputVar1.start,
              target: outputVar1.start,
              identifier_name: null,
            ),
          ],
        );
        expect(mapping.files, equals([input]));
      });
    });
    group('from parse()', () {
      group('are null', () {
        test('with no sourcesContent field', () {
          final mapping = parse_sourcemap(expectedMap) as SourcemapSingle;
          expect(mapping.files, equals([null]));
        });
        test('with null sourcesContent values', () {
          final map = Map<String, dynamic>.from(expectedMap);
          map['sourcesContent'] = [null];
          final mapping = parse_sourcemap(map) as SourcemapSingle;
          expect(mapping.files, equals([null]));
        });
        test('with a too-short sourcesContent', () {
          final map = Map<String, dynamic>.from(expectedMap);
          map['sourcesContent'] = <dynamic>[];
          final mapping = parse_sourcemap(map) as SourcemapSingle;
          expect(mapping.files, equals([null]));
        });
      });
      test('are parsed from sourcesContent', () {
        final map = Map<String, dynamic>.from(expectedMap);
        map['sourcesContent'] = ['hello, world!'];
        final mapping = parse_sourcemap(map) as SourcemapSingle;
        final file = mapping.files[0]!;
        expect(file.url, equals(Uri.parse('input.dart')));
        expect(file.getText(0), equals('hello, world!'));
      });
    });
  });
}
