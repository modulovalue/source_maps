import 'dart:convert';
import 'dart:math';

import 'package:source_maps2/json_to_sourcemap.dart';
import 'package:source_maps2/sourcemap.dart';
import 'package:source_maps2/sourcemap_builder.dart';
import 'package:source_maps2/sourcemap_span_for.dart';
import 'package:source_maps2/sourcemap_to_json.dart';
import 'package:source_maps2/vlq.dart';
import 'package:source_span/source_span.dart';
import 'package:test/test.dart';

void main() {
  group("end-to-end", () {
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
      final map = sourcemap_single_to_json(
        include_source_contents: false,
        sourcemap: (SourcemapBuilderImpl()
              ..add_span(source: inputVar1, target: outputVar1)
              ..add_span(source: inputFunction, target: outputFunction)
              ..add_span(source: inputVar2, target: outputVar2)
              ..add_span(source: inputExpr, target: outputExpr))
            .build(
          file_url: output.url.toString(),
        ),
      );
      final mapping = sourcemap_from_json(map);
      check(outputVar1, mapping, inputVar1, false);
      check(outputVar2, mapping, inputVar2, false);
      check(outputFunction, mapping, inputFunction, false);
      check(outputExpr, mapping, inputExpr, false);
    });
    test('build + parse - no symbols', () {
      final map = sourcemap_single_to_json(
        include_source_contents: false,
        sourcemap: (SourcemapBuilderImpl()
              ..add_span(source: inputVar1NoSymbol, target: outputVar1NoSymbol)
              ..add_span(source: inputFunctionNoSymbol, target: outputFunctionNoSymbol)
              ..add_span(source: inputVar2NoSymbol, target: outputVar2NoSymbol)
              ..add_span(source: inputExpr, target: outputExpr))
            .build(
          file_url: output.url.toString(),
        ),
      );
      final mapping = sourcemap_from_json(map);
      check(outputVar1NoSymbol, mapping, inputVar1NoSymbol, false);
      check(outputVar2NoSymbol, mapping, inputVar2NoSymbol, false);
      check(outputFunctionNoSymbol, mapping, inputFunctionNoSymbol, false);
      check(outputExpr, mapping, inputExpr, false);
    });
    test('build + parse, repeated entries', () {
      final map = sourcemap_single_to_json(
        include_source_contents: false,
        sourcemap: (SourcemapBuilderImpl()
              ..add_span(source: inputVar1, target: outputVar1)
              ..add_span(source: inputVar1, target: outputVar1)
              ..add_span(source: inputFunction, target: outputFunction)
              ..add_span(source: inputFunction, target: outputFunction)
              ..add_span(source: inputVar2, target: outputVar2)
              ..add_span(source: inputVar2, target: outputVar2)
              ..add_span(source: inputExpr, target: outputExpr)
              ..add_span(source: inputExpr, target: outputExpr))
            .build(
          file_url: output.url.toString(),
        ),
      );
      final mapping = sourcemap_from_json(map);
      check(outputVar1, mapping, inputVar1, false);
      check(outputVar2, mapping, inputVar2, false);
      check(outputFunction, mapping, inputFunction, false);
      check(outputExpr, mapping, inputExpr, false);
    });
    test('build + parse - no symbols, repeated entries', () {
      final map = sourcemap_single_to_json(
        include_source_contents: false,
        sourcemap: (SourcemapBuilderImpl()
              ..add_span(source: inputVar1NoSymbol, target: outputVar1NoSymbol)
              ..add_span(source: inputVar1NoSymbol, target: outputVar1NoSymbol)
              ..add_span(source: inputFunctionNoSymbol, target: outputFunctionNoSymbol)
              ..add_span(source: inputFunctionNoSymbol, target: outputFunctionNoSymbol)
              ..add_span(source: inputVar2NoSymbol, target: outputVar2NoSymbol)
              ..add_span(source: inputVar2NoSymbol, target: outputVar2NoSymbol)
              ..add_span(source: inputExpr, target: outputExpr))
            .build(
          file_url: output.url.toString(),
        ),
      );
      final mapping = sourcemap_from_json(map);
      check(outputVar1NoSymbol, mapping, inputVar1NoSymbol, false);
      check(outputVar2NoSymbol, mapping, inputVar2NoSymbol, false);
      check(outputFunctionNoSymbol, mapping, inputFunctionNoSymbol, false);
      check(outputExpr, mapping, inputExpr, false);
    });
    test('build + parse with file', () {
      final json = jsonEncode(
        sourcemap_single_to_json(
          include_source_contents: false,
          sourcemap: (SourcemapBuilderImpl()
                ..add_span(source: inputVar1, target: outputVar1)
                ..add_span(source: inputFunction, target: outputFunction)
                ..add_span(source: inputVar2, target: outputVar2)
                ..add_span(source: inputExpr, target: outputExpr))
              .build(
            file_url: output.url.toString(),
          ),
        ),
      );
      final mapping = sourcemap_from_json(
        jsonDecode(json),
      );
      check(outputVar1, mapping, inputVar1, true);
      check(outputVar2, mapping, inputVar2, true);
      check(outputFunction, mapping, inputFunction, true);
      check(outputExpr, mapping, inputExpr, true);
    });
  });
  group("parser test", () {
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

    test('parse', () {
      final mapping = sourcemap_from_json(expectedMap);
      check(outputVar1, mapping, inputVar1, false);
      check(outputVar2, mapping, inputVar2, false);
      check(outputFunction, mapping, inputFunction, false);
      check(outputExpr, mapping, inputExpr, false);
    });
    test('parse + json', () {
      final mapping = sourcemap_from_json(
        jsonDecode(jsonEncode(expectedMap)),
      );
      check(outputVar1, mapping, inputVar1, false);
      check(outputVar2, mapping, inputVar2, false);
      check(outputFunction, mapping, inputFunction, false);
      check(outputExpr, mapping, inputExpr, false);
    });
    test('parse with file', () {
      final mapping = sourcemap_from_json(expectedMap);
      check(outputVar1, mapping, inputVar1, true);
      check(outputVar2, mapping, inputVar2, true);
      check(outputFunction, mapping, inputFunction, true);
      check(outputExpr, mapping, inputExpr, true);
    });
    test('parse with no source location', () {
      final map = sourcemap_from_json(jsonDecode(jsonEncode(_mapWithNoSourceLocation))) as SourcemapSingle;
      expect(map.lines.length, 1);
      expect(map.lines.first.entries.length, 1);
      final entry = map.lines.first.entries.first;
      expect(entry.column, 0);
      expect(entry.source_url_id, null);
      expect(entry.source_column, null);
      expect(entry.source_line, null);
      expect(entry.source_name_id, null);
    });
    test('parse with source location and no name', () {
      final map = sourcemap_from_json(jsonDecode(jsonEncode(_mapWithSourceLocation))) as SourcemapSingle;
      expect(map.lines.length, 1);
      expect(map.lines.first.entries.length, 1);
      final entry = map.lines.first.entries.first;
      expect(entry.column, 0);
      expect(entry.source_url_id, 0);
      expect(entry.source_column, 0);
      expect(entry.source_line, 0);
      expect(entry.source_name_id, null);
    });
    test('parse with source location and missing names entry', () {
      final map = sourcemap_from_json(jsonDecode(jsonEncode(_mapWithSourceLocationAndMissingNames)))
          as SourcemapSingle;
      expect(map.lines.length, 1);
      expect(map.lines.first.entries.length, 1);
      final entry = map.lines.first.entries.first;
      expect(entry.column, 0);
      expect(entry.source_url_id, 0);
      expect(entry.source_column, 0);
      expect(entry.source_line, 0);
      expect(entry.source_name_id, null);
    });
    test('parse with source location and name', () {
      final map =
          sourcemap_from_json(jsonDecode(jsonEncode(_mapWithSourceLocationAndName))) as SourcemapSingle;
      expect(map.lines.length, 1);
      expect(map.lines.first.entries.length, 1);
      final entry = map.lines.first.entries.first;
      expect(entry.source_url_id, 0);
      expect(entry.source_url_id, 0);
      expect(entry.source_column, 0);
      expect(entry.source_line, 0);
      expect(entry.source_name_id, 0);
    });
    test('parse with source root', () {
      final inputMap = Map<String, dynamic>.from(_mapWithSourceLocation);
      inputMap['sourceRoot'] = '/pkg/';
      final mapping = sourcemap_from_json(inputMap) as SourcemapSingle;
      expect(
        span_for_sourcemap(
          sourcemap: mapping,
          line: 0,
          column: 0,
          uri: null,
          files: null,
        )?.sourceUrl,
        Uri.parse('/pkg/input.dart'),
      );
      expect(
        span_for_sourcemap(
          sourcemap: mapping,
          line: 0,
          column: 0,
          uri: 'ignored.dart',
          files: null,
        )?.sourceUrl,
        Uri.parse('/pkg/input.dart'),
      );
      const newSourceRoot = '/new/';
      inputMap['sourceRoot'] = newSourceRoot;
      expect(
        sourcemap_single_to_json(
          include_source_contents: false,
          sourcemap: mapping.copy_with_new_source_root(newSourceRoot),
        ),
        equals(inputMap),
      );
    });
    test('parse with map URL', () {
      final inputMap = Map<String, dynamic>.from(_mapWithSourceLocation);
      inputMap['sourceRoot'] = 'pkg/';
      final mapping = sourcemap_from_json(
        inputMap,
        source_map_file_url: Uri.tryParse('file:///path/to/map'),
      );
      expect(
        span_for_sourcemap(
          sourcemap: mapping,
          line: 0,
          column: 0,
          uri: null,
          files: null,
        )?.sourceUrl,
        Uri.parse('file:///path/to/pkg/input.dart'),
      );
    });
    group('parse with bundle', () {
      final mapping = sourcemap_from_json(
        _sourceMapBundle,
        source_map_file_url: Uri.tryParse('file:///path/to/map'),
      );
      test('simple', () {
        expect(
          span_for_sourcemap(
            sourcemap: mapping,
            line: 0,
            column: 0,
            uri: Uri.file('/path/to/output.dart').toString(),
            files: null,
          )?.sourceUrl,
          Uri.parse('file:///path/to/pkg/input1.dart'),
        );
        expect(
          span_for_sourcemap(
            sourcemap: mapping,
            line: 0,
            column: 0,
            uri: Uri.file('/path/to/output2.dart').toString(),
            files: null,
          )?.sourceUrl,
          Uri.parse('file:///path/to/pkg/input2.dart'),
        );
        expect(
          span_for_sourcemap(
            sourcemap: mapping,
            line: 0,
            column: 0,
            uri: Uri.file('/path/to/3/output.dart').toString(),
            files: null,
          )?.sourceUrl,
          Uri.parse('file:///path/to/pkg/input3.dart'),
        );
        expect(
          span_for_sourcemap(
            sourcemap: mapping,
            line: 0,
            column: 0,
            uri: 'file:///path/to/output.dart',
            files: null,
          )?.sourceUrl,
          Uri.parse('file:///path/to/pkg/input1.dart'),
        );
        expect(
          span_for_sourcemap(
            sourcemap: mapping,
            line: 0,
            column: 0,
            uri: 'file:///path/to/output2.dart',
            files: null,
          )?.sourceUrl,
          Uri.parse('file:///path/to/pkg/input2.dart'),
        );
        expect(
          span_for_sourcemap(
            sourcemap: mapping,
            line: 0,
            column: 0,
            uri: 'file:///path/to/3/output.dart',
            files: null,
          )?.sourceUrl,
          Uri.parse('file:///path/to/pkg/input3.dart'),
        );
      });
      test('package uris', () {
        expect(
          span_for_sourcemap(
            sourcemap: mapping,
            line: 0,
            column: 0,
            uri: Uri.parse('package:1/output.dart').toString(),
            files: null,
          )?.sourceUrl,
          Uri.parse('file:///path/to/pkg/input1.dart'),
        );
        expect(
          span_for_sourcemap(
            sourcemap: mapping,
            line: 0,
            column: 0,
            uri: Uri.parse('package:2/output2.dart').toString(),
            files: null,
          )?.sourceUrl,
          Uri.parse('file:///path/to/pkg/input2.dart'),
        );
        expect(
          span_for_sourcemap(
            sourcemap: mapping,
            line: 0,
            column: 0,
            uri: Uri.parse('package:3/output.dart').toString(),
            files: null,
          )?.sourceUrl,
          Uri.parse('file:///path/to/pkg/input3.dart'),
        );
        expect(
          span_for_sourcemap(
            sourcemap: mapping,
            line: 0,
            column: 0,
            uri: 'package:1/output.dart',
            files: null,
          )?.sourceUrl,
          Uri.parse('file:///path/to/pkg/input1.dart'),
        );
        expect(
          span_for_sourcemap(
            sourcemap: mapping,
            line: 0,
            column: 0,
            uri: 'package:2/output2.dart',
            files: null,
          )?.sourceUrl,
          Uri.parse('file:///path/to/pkg/input2.dart'),
        );
        expect(
          span_for_sourcemap(
            sourcemap: mapping,
            line: 0,
            column: 0,
            uri: 'package:3/output.dart',
            files: null,
          )?.sourceUrl,
          Uri.parse('file:///path/to/pkg/input3.dart'),
        );
      });
      test('unmapped path', () {
        var span = span_for_sourcemap(
          sourcemap: mapping,
          line: 0,
          column: 0,
          uri: 'unmapped_output.dart',
          files: null,
        )!;
        expect(
          span.sourceUrl,
          Uri.parse('unmapped_output.dart'),
        );
        expect(
          span.start.line,
          equals(0),
        );
        expect(
          span.start.column,
          equals(0),
        );
        span = span_for_sourcemap(
          sourcemap: mapping,
          line: 10,
          column: 5,
          uri: 'unmapped_output.dart',
          files: null,
        )!;
        expect(
          span.sourceUrl,
          Uri.parse('unmapped_output.dart'),
        );
        expect(
          span.start.line,
          equals(10),
        );
        expect(
          span.start.column,
          equals(5),
        );
      });
      test('missing path', () {
        expect(
          () => span_for_sourcemap(
            sourcemap: mapping,
            line: 0,
            column: 0,
            uri: null,
            files: null,
          ),
          throwsA(anything),
        );
      });
      test('incomplete paths', () {
        expect(
          span_for_sourcemap(
            sourcemap: mapping,
            line: 0,
            column: 0,
            uri: 'output.dart',
            files: null,
          )?.sourceUrl,
          Uri.parse('file:///path/to/pkg/input1.dart'),
        );
        expect(
          span_for_sourcemap(
            sourcemap: mapping,
            line: 0,
            column: 0,
            uri: 'output2.dart',
            files: null,
          )?.sourceUrl,
          Uri.parse('file:///path/to/pkg/input2.dart'),
        );
        expect(
          span_for_sourcemap(
            sourcemap: mapping,
            line: 0,
            column: 0,
            uri: '3/output.dart',
            files: null,
          )?.sourceUrl,
          Uri.parse('file:///path/to/pkg/input3.dart'),
        );
      });
      test('parseExtended', () {
        final mapping = sourcemap_from_json(
          _sourceMapBundle,
          source_map_file_url: Uri.tryParse('file:///path/to/map'),
        );
        expect(
          span_for_sourcemap(
            sourcemap: mapping,
            line: 0,
            column: 0,
            uri: 'output.dart',
            files: null,
          )?.sourceUrl,
          Uri.parse('file:///path/to/pkg/input1.dart'),
        );
        expect(
          span_for_sourcemap(
            sourcemap: mapping,
            line: 0,
            column: 0,
            uri: 'output2.dart',
            files: null,
          )?.sourceUrl,
          Uri.parse('file:///path/to/pkg/input2.dart'),
        );
        expect(
          span_for_sourcemap(
            sourcemap: mapping,
            line: 0,
            column: 0,
            uri: '3/output.dart',
            files: null,
          )?.sourceUrl,
          Uri.parse('file:///path/to/pkg/input3.dart'),
        );
      });
      test('build bundle incrementally', () {
        final mapping = SourcemapCollectionImpl();
        mapping.addMapping(
          sourcemap_from_json(
            _mapWithSourceLocationAndName1,
            source_map_file_url: Uri.tryParse('file:///path/to/map'),
          ) as SourcemapSingle,
        );
        expect(
          span_for_sourcemap(
            sourcemap: mapping,
            line: 0,
            column: 0,
            uri: 'output.dart',
            files: null,
          )?.sourceUrl,
          Uri.parse('file:///path/to/pkg/input1.dart'),
        );
        expect(mapping.containsMapping('output2.dart'), isFalse);
        mapping.addMapping(
          sourcemap_from_json(
            _mapWithSourceLocationAndName2,
            source_map_file_url: Uri.tryParse('file:///path/to/map'),
          ) as SourcemapSingle,
        );
        expect(mapping.containsMapping('output2.dart'), isTrue);
        expect(
          span_for_sourcemap(
            sourcemap: mapping,
            line: 0,
            column: 0,
            uri: 'output2.dart',
            files: null,
          )?.sourceUrl,
          Uri.parse('file:///path/to/pkg/input2.dart'),
        );
        expect(mapping.containsMapping('3/output.dart'), isFalse);
        mapping.addMapping(
          sourcemap_from_json(
            _mapWithSourceLocationAndName3,
            source_map_file_url: Uri.tryParse('file:///path/to/map'),
          ) as SourcemapSingle,
        );
        expect(mapping.containsMapping('3/output.dart'), isTrue);
        expect(
          span_for_sourcemap(
            sourcemap: mapping,
            line: 0,
            column: 0,
            uri: '3/output.dart',
            files: null,
          )?.sourceUrl,
          Uri.parse('file:///path/to/pkg/input3.dart'),
        );
      });
      // Test that the source map can handle cases where the uri passed in is
      // not from the expected host but it is still unambiguous which source
      // map should be used.
      test('different paths', () {
        expect(
          span_for_sourcemap(
            sourcemap: mapping,
            line: 0,
            column: 0,
            uri: Uri.parse('http://localhost/output.dart').toString(),
            files: null,
          )?.sourceUrl,
          Uri.parse('file:///path/to/pkg/input1.dart'),
        );
        expect(
          span_for_sourcemap(
            sourcemap: mapping,
            line: 0,
            column: 0,
            uri: Uri.parse('http://localhost/output2.dart').toString(),
            files: null,
          )?.sourceUrl,
          Uri.parse('file:///path/to/pkg/input2.dart'),
        );
        expect(
          span_for_sourcemap(
            sourcemap: mapping,
            line: 0,
            column: 0,
            uri: Uri.parse('http://localhost/3/output.dart').toString(),
            files: null,
          )?.sourceUrl,
          Uri.parse('file:///path/to/pkg/input3.dart'),
        );
        expect(
          span_for_sourcemap(
            sourcemap: mapping,
            line: 0,
            column: 0,
            uri: 'http://localhost/output.dart',
            files: null,
          )?.sourceUrl,
          Uri.parse('file:///path/to/pkg/input1.dart'),
        );
        expect(
          span_for_sourcemap(
            sourcemap: mapping,
            line: 0,
            column: 0,
            uri: 'http://localhost/output2.dart',
            files: null,
          )?.sourceUrl,
          Uri.parse('file:///path/to/pkg/input2.dart'),
        );
        expect(
          span_for_sourcemap(
            sourcemap: mapping,
            line: 0,
            column: 0,
            uri: 'http://localhost/3/output.dart',
            files: null,
          )?.sourceUrl,
          Uri.parse('file:///path/to/pkg/input3.dart'),
        );
      });
    });
    test('parse and re-emit', () {
      for (final expected in [
        expectedMap,
        _mapWithNoSourceLocation,
        _mapWithSourceLocation,
        _mapWithSourceLocationAndName
      ]) {
        SourcemapSingle mapping = sourcemap_from_json(expected) as SourcemapSingle;
        expect(
          sourcemap_single_to_json(
            include_source_contents: false,
            sourcemap: mapping,
          ),
          equals(expected),
        );
        mapping = sourcemap_from_json(expected) as SourcemapSingle;
        expect(
          sourcemap_single_to_json(
            include_source_contents: false,
            sourcemap: mapping,
          ),
          equals(expected),
        );
      }
      final mapping = sourcemap_from_json(_sourceMapBundle) as SourcemapCollection;
      expect(
        sourcemap_bundle_to_json(
          sourcemap: mapping,
          include_source_contents: false,
        ),
        equals(_sourceMapBundle),
      );
    });
    test('parse extensions', () {
      final map = Map<String, dynamic>.from(expectedMap);
      map['x_foo'] = 'a';
      map['x_bar'] = [3];
      final mapping = sourcemap_from_json(map) as SourcemapSingle;
      expect(
        sourcemap_single_to_json(
          include_source_contents: false,
          sourcemap: mapping,
        ),
        equals(map),
      );
      expect(
        mapping.extensions['x_foo'],
        equals('a'),
      );
      expect(
        (mapping.extensions['x_bar'] as List?)!.first,
        equals(3),
      );
    });
    group('source files', () {
      group('from fromEntries()', () {
        test('are null for non-FileLocations', () {
          final builder = SourcemapBuilderImpl();
          builder.add_location(
            const SourcemapLocationImpl(
              offset: 10,
              line: 1,
              column: 8,
              file: null,
              sourceUrl: null,
            ),
            outputVar1.start,
            null,
          );
          expect(
            builder.build(file_url: "some_url").files,
            [null],
          );
        });
        test("use a file location's file", () {
          final builder = SourcemapBuilderImpl();
          builder.add_location(
            inputVar1.start,
            outputVar1.start,
            null,
          );
          expect(
            builder.build(file_url: "some_url").files.single?.url,
            input.url,
          );
          expect(
            builder.build(file_url: "some_url").files.single?.content,
            input.content,
          );
        });
      });
      group('from parse()', () {
        group('are null', () {
          test('with no sourcesContent field', () {
            final mapping = sourcemap_from_json(expectedMap) as SourcemapSingle;
            expect(
              mapping.files,
              equals([null]),
            );
          });
          test('with null sourcesContent values', () {
            final map = Map<String, dynamic>.from(expectedMap);
            map['sourcesContent'] = [null];
            final mapping = sourcemap_from_json(map) as SourcemapSingle;
            expect(
              mapping.files,
              equals([null]),
            );
          });
          test('with a too-short sourcesContent', () {
            final map = Map<String, dynamic>.from(expectedMap);
            map['sourcesContent'] = <dynamic>[];
            final mapping = sourcemap_from_json(map) as SourcemapSingle;
            expect(
              mapping.files,
              equals([null]),
            );
          });
        });
        test('are parsed from sourcesContent', () {
          final map = Map<String, dynamic>.from(expectedMap);
          map['sourcesContent'] = ['hello, world!'];
          final mapping = sourcemap_from_json(map) as SourcemapSingle;
          final file = mapping.files[0]!;
          expect(
            file.url,
            equals(Uri.parse('input.dart')),
          );
          expect(
            file.content,
            equals('hello, world!'),
          );
        });
      });
    });
  });
  group("builder", () {
    test('builder - with span', () {
      final builder = SourcemapBuilderImpl();
      builder.add_span(source: inputVar1, target: outputVar1);
      builder.add_span(source: inputFunction, target: outputFunction);
      builder.add_span(source: inputVar2, target: outputVar2);
      builder.add_span(source: inputExpr, target: outputExpr);
      final map = sourcemap_single_to_json(
        include_source_contents: false,
        sourcemap: builder.build(
          file_url: output.url.toString(),
        ),
      );
      expect(
        map,
        equals(expectedMap),
      );
    });
    test('builder - with location', () {
      final str = jsonEncode(
        sourcemap_single_to_json(
          include_source_contents: false,
          sourcemap: (SourcemapBuilderImpl()
                ..add_location(inputVar1.start, outputVar1.start, 'longVar1')
                ..add_location(inputFunction.start, outputFunction.start, 'longName')
                ..add_location(inputVar2.start, outputVar2.start, 'longVar2')
                ..add_location(inputExpr.start, outputExpr.start, null))
              .build(
            file_url: output.url.toString(),
          ),
        ),
      );
      expect(
        str,
        jsonEncode(expectedMap),
      );
    });
  });
  group('binary search', () {
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

    test('empty', () {
      expect(binary_search(<int>[])((final x) => true), -1);
    });
    test('single element', () {
      expect(binary_search([1])((final x) => true), 0);
      expect(binary_search([1])((final x) => false), 1);
    });
    test('no matches', () {
      final list = [1, 2, 3, 4, 5, 6, 7];
      expect(binary_search(list)((final x) => false), list.length);
    });
    test('all match', () {
      final list = [1, 2, 3, 4, 5, 6, 7];
      expect(binary_search(list)((final x) => true), 0);
    });
    test('compare with linear search', () {
      for (var size = 0; size < 100; size++) {
        final list = <int>[];
        for (var i = 0; i < size; i++) {
          list.add(i);
        }
        for (var pos = 0; pos <= size; pos++) {
          expect(
            binary_search<int>(list)((final x) => x >= pos),
            _linearSearch(list)((final x) => x >= pos),
          );
        }
      }
    });
  });
  group("vlq", () {
    void _checkEncodeDecode(
      final int value,
    ) {
      final encoded = Vlq.encode_vlq(value);
      expect(Vlq.decode_vlq(encoded.iterator), value);
      expect(Vlq.decode_vlq(encoded.join('').split('').iterator), value);
    }

    test('encode and decode - simple values', () {
      expect(Vlq.encode_vlq(1).join(''), 'C');
      expect(Vlq.encode_vlq(2).join(''), 'E');
      expect(Vlq.encode_vlq(3).join(''), 'G');
      expect(Vlq.encode_vlq(100).join(''), 'oG');
      expect(Vlq.decode_vlq('C'.split('').iterator), 1);
      expect(Vlq.decode_vlq('E'.split('').iterator), 2);
      expect(Vlq.decode_vlq('G'.split('').iterator), 3);
      expect(Vlq.decode_vlq('oG'.split('').iterator), 100);
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
        expect(Vlq.encode_vlq(minInt).join(''), 'hgggggE');
        expect(Vlq.decode_vlq('hgggggE'.split('').iterator), minInt);
        expect(
          () => Vlq.encode_vlq(maxInt + 1),
          throwsA(anything),
        );
        expect(
          () => Vlq.encode_vlq(maxInt + 2),
          throwsA(anything),
        );
        expect(
          () => Vlq.encode_vlq(minInt - 1),
          throwsA(anything),
        );
        expect(
          () => Vlq.encode_vlq(minInt - 2),
          throwsA(anything),
        );
        // if we allowed more than 32 bits, these would be the expected encodings
        // for the large numbers above.
        expect(
          () => Vlq.decode_vlq('ggggggE'.split('').iterator),
          throwsA(anything),
        );
        expect(
          () => Vlq.decode_vlq('igggggE'.split('').iterator),
          throwsA(anything),
        );
        expect(
          () => Vlq.decode_vlq('jgggggE'.split('').iterator),
          throwsA(anything),
        );
        expect(
          () => Vlq.decode_vlq('lgggggE'.split('').iterator),
          throwsA(anything),
        );
      },
      // This test uses integers so large they overflow in JS.
      testOn: 'dart-vm',
    );
  });
}

/// Content of the source file
const String inputContent = '''
/** this is a comment. */
int longVar1 = 3;

// this is a comment too
int longName(int longVar2) {
  return longVar1 + longVar2;
}
''';
final input = SourcemapFileImpl(
  content: inputContent,
  url: Uri.parse('input.dart'),
);

/// A span in the input file.
SourcemapSpan _ispan(
  final int start,
  final int end, [
  final bool isIdentifier = false,
]) {
  final span = SourceFile.fromString(
    input.content,
    url: input.url,
  ).span(
    start,
    end,
  );
  return SourcemapSpanImpl(
    start: SourcemapLocationImpl(
      offset: start,
      line: span.start.line,
      column: span.start.column,
      sourceUrl: input.url,
      file: input,
    ),
    end: SourcemapLocationImpl(
      offset: end,
      line: span.end.line,
      column: span.end.column,
      sourceUrl: input.url,
      file: input,
    ),
    text: input.content.substring(start, end),
    is_identifier: isIdentifier,
    sourceUrl: input.url,
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
const outputContent = '''
var x = 3;
f(y) => x + y;
''';

final output = SourcemapFileImpl(
  content: outputContent,
  url: Uri.parse('output.dart'),
);

/// A span in the output file
SourcemapSpan _ospan(
  final int start,
  final int end, [
  final bool isIdentifier = false,
]) {
  final span = SourceFile.fromString(
    output.content,
    url: output.url,
  ).span(
    start,
    end,
  );
  return SourcemapSpanImpl(
    start: SourcemapLocationImpl(
      offset: start,
      line: span.start.line,
      column: span.start.column,
      sourceUrl: output.url,
      file: output,
    ),
    end: SourcemapLocationImpl(
      offset: end,
      line: span.end.line,
      column: span.end.column,
      sourceUrl: output.url,
      file: output,
    ),
    text: output.content.substring(start, end),
    sourceUrl: output.url,
    is_identifier: isIdentifier,
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
  final loc = outputSpan.start;
  final line = loc.line;
  final column = loc.column;
  final files = () {
    if (realOffsets) {
      return {
        'input.dart': input,
      };
    } else {
      return null;
    }
  }();
  final span = span_for_sourcemap(
    sourcemap: mapping,
    line: line,
    column: column,
    files: files,
    uri: null,
  )!;
  final span2 = span_for_sourcemap(
    sourcemap: mapping,
    line: loc.line,
    column: loc.column,
    files: files,
    uri: loc.sourceUrl?.toString(),
  )!;
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
