// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:math';

// TODO remove this dependency.
import 'package:source_span/source_span.dart';

import 'builder.dart';
import 'source_map_span.dart';

/// Parses a source map or source map bundle.
///
/// [mapUrl], which may be either a [String] or a [Uri], indicates the URL of
/// the source map file itself. If it's passed, any URLs in the source
/// map will be interpreted as relative to this URL when generating spans.
// TODO(tjblasi): Ignore the first line of [jsonMap] if the JSON safety string `)]}'` begins the string representation of the map.
Sourcemap parse_sourcemap(
  final dynamic json, {
  final Uri? mapUrl,
}) {
  if (json is List) {
    return SourcemapBundle.fromJson(
      json,
      mapUrl: mapUrl,
    );
  } else if (json is Map<dynamic, dynamic>) {
    final map = json;
    if (map['version'] != 3) {
      throw ArgumentError(
        'unexpected source map version: ${map["version"]}. '
        'Only version 3 is supported.',
      );
    } else {
      if (map.containsKey('sections')) {
        if (map.containsKey('mappings') || map.containsKey('sources') || map.containsKey('names')) {
          throw const FormatException(
            'map containing "sections" '
            'cannot contain "mappings", "sources", or "names".',
          );
        } else {
          return SourcemapMultisection.fromJson(
            map['sections'] as List<dynamic>,
            mapUrl: mapUrl,
          );
        }
      } else {
        return SourcemapSingle.fromJson(
          map,
          mapUrl: mapUrl,
        );
      }
    }
  } else {
    throw Exception("Invalid type. ${json.runtimeType}");
  }
}

/// A mapping parsed out of a source map.
abstract class Sourcemap {
  /// Returns the span associated with [line] and [column].
  ///
  /// [uri] is the optional location of the output file to find the span for
  /// to disambiguate cases where a mapping may have different mappings for
  /// different output files.
  SourcemapSpan? span_for(
    final int line,
    final int column, {
    final Map<String, SourceFile>? files,
    final String? uri,
  });

  R match<R>({
    required final R Function(SourcemapMultisection) multi,
    required final R Function(SourcemapBundle) bundle,
    required final R Function(SourcemapSingle) single,
  });
}

extension MappingSpanForLocation on Sourcemap {
  /// Returns the span associated with [location].
  SourcemapSpan? span_for_location(
      final SourceLocation location, {
        final Map<String, SourceFile>? files,
      }) {
    return span_for(
      location.line,
      location.column,
      uri: location.sourceUrl?.toString(),
      files: files,
    );
  }
}

/// A meta-level map containing sections.
class SourcemapMultisection implements Sourcemap {
  /// For each section, the start line offset.
  final List<int> _lineStart = <int>[];

  /// For each section, the start column offset.
  final List<int> _columnStart = <int>[];

  /// For each section, the actual source map information, which is not adjusted
  /// for offsets.
  final List<Sourcemap> _maps = <Sourcemap>[];

  /// Creates a section mapping from json.
  SourcemapMultisection.fromJson(
    final List<dynamic> sections, {
    final Uri? mapUrl,
  }) {
    for (final section in sections) {
      final offset = (section as Map<String, dynamic>)['offset'] as int?;
      if (offset == null) {
        throw const FormatException('section missing offset');
      } else {
        final line = (section['offset'] as Map<String, dynamic>)['line'] as int?;
        if (line == null) {
          throw const FormatException('offset missing line');
        } else {
          final column = (section['offset'] as Map<String, dynamic>)['column'] as int?;
          if (column == null) {
            throw const FormatException('offset missing column');
          } else {
            _lineStart.add(line);
            _columnStart.add(column);
            final dynamic url = section['url'];
            final dynamic map = section['map'];
            if (url != null && map != null) {
              throw const FormatException("section can't use both url and map entries");
            } else if (map != null) {
              _maps.add(
                parse_sourcemap(
                  map as Object,
                  mapUrl: mapUrl,
                ),
              );
            } else {
              throw const FormatException(
                'section missing url or map',
              );
            }
          }
        }
      }
    }
    if (_lineStart.isEmpty) {
      throw const FormatException(
        'expected at least one section',
      );
    }
  }

  int _indexFor(
    final int line,
    final int column,
  ) {
    for (int i = 0; i < _lineStart.length; i++) {
      if (line < _lineStart[i]) {
        return i - 1;
      } else {
        if (line == _lineStart[i] && column < _columnStart[i]) {
          return i - 1;
        } else {
          // Continue.
        }
      }
    }
    return _lineStart.length - 1;
  }

  @override
  SourcemapSpan? span_for(
    final int line,
    final int column, {
    final Map<String, SourceFile>? files,
    final String? uri,
  }) {
    // TODO(jacobr): perhaps verify that targetUrl matches the actual uri
    // or at least ends in the same file name.
    final index = _indexFor(line, column);
    return _maps[index].span_for(
      line - _lineStart[index],
      column - _columnStart[index],
      files: files,
    );
  }

  @override
  String toString() {
    final buff = StringBuffer('$runtimeType : [');
    for (int i = 0; i < _lineStart.length; i++) {
      buff
        ..write('(')
        ..write(_lineStart[i])
        ..write(',')
        ..write(_columnStart[i])
        ..write(':')
        ..write(_maps[i])
        ..write(')');
    }
    buff.write(']');
    return buff.toString();
  }

  @override
  R match<R>({
    required final R Function(SourcemapMultisection) multi,
    required final R Function(SourcemapBundle) bundle,
    required final R Function(SourcemapSingle) single,
  }) =>
      multi(this);
}

class SourcemapBundle implements Sourcemap {
  final Map<String, SourcemapSingle> _mappings = {};

  SourcemapBundle();

  SourcemapBundle.fromJson(
    final List<dynamic> json, {
    final Uri? mapUrl,
  }) {
    for (final map in json) {
      addMapping(
        parse_sourcemap(map as Object, mapUrl: mapUrl) as SourcemapSingle,
      );
    }
  }

  void addMapping(
    final SourcemapSingle mapping,
  ) {
    // TODO(jacobr): verify that targetUrl is valid uri instead of a windows
    // path.
    // TODO: Remove type arg https://github.com/dart-lang/sdk/issues/42227
    final targetUrl = ArgumentError.checkNotNull<String>(mapping.targetUrl, 'mapping.targetUrl');
    _mappings[targetUrl] = mapping;
  }

  /// Encodes the Mapping mappings as a json map.
  List<dynamic> toJson() => _mappings.values.map((final v) => v.toJson()).toList();

  @override
  String toString() {
    final buff = StringBuffer();
    for (final map in _mappings.values) {
      buff.write(map.toString());
    }
    return buff.toString();
  }

  bool containsMapping(
    final String url,
  ) =>
      _mappings.containsKey(url);

  @override
  SourcemapSpan? span_for(
    final int line,
    final int column, {
    final Map<String, SourceFile>? files,
    String? uri,
  }) {
    // TODO: Remove type arg https://github.com/dart-lang/sdk/issues/42227
    // ignore: parameter_assignments
    uri = ArgumentError.checkNotNull<String>(uri, 'uri');
    // Find the longest suffix of the uri that matches the sourcemap
    // where the suffix starts after a path segment boundary.
    // We consider ":" and "/" as path segment boundaries so that
    // "package:" uris can be handled with minimal special casing. Having a
    // few false positive path segment boundaries is not a significant issue
    // as we prefer the longest matching prefix.
    // Using package:path `path.split` to find path segment boundaries would
    // not generate all of the path segment boundaries we want for "package:"
    // urls as "package:package_name" would be one path segment when we want
    // "package" and "package_name" to be sepearate path segments.
    bool onBoundary = true;
    final separatorCodeUnits = ['/'.codeUnitAt(0), ':'.codeUnitAt(0)];
    for (int i = 0; i < uri.length; ++i) {
      if (onBoundary) {
        final candidate = uri.substring(i);
        final candidateMapping = _mappings[candidate];
        if (candidateMapping != null) {
          return candidateMapping.span_for(line, column, files: files, uri: candidate);
        }
      }
      onBoundary = separatorCodeUnits.contains(uri.codeUnitAt(i));
    }
    // Note: when there is no source map for an uri, this behaves like an
    // identity function, returning the requested location as the result.
    //
    // Create a mock offset for the output location. We compute it in terms
    // of the input line and column to minimize the chances that two different
    // line and column locations are mapped to the same offset.
    final offset = line * 1000000 + column;
    final location = SourceLocation(
      offset,
      line: line,
      column: column,
      sourceUrl: Uri.parse(uri),
    );
    return SourcemapSpanImpl(
      location,
      location,
      '',
      false,
    );
  }

  @override
  R match<R>({
    required final R Function(SourcemapMultisection) multi,
    required final R Function(SourcemapBundle) bundle,
    required final R Function(SourcemapSingle) single,
  }) =>
      bundle(this);
}

/// A map containing direct source mappings.
class SourcemapSingle implements Sourcemap {
  /// Source urls used in the mapping, indexed by id.
  final List<String> urls;

  /// Source names used in the mapping, indexed by id.
  final List<String> names;

  /// The [SourceFile]s to which the entries in [lines] refer.
  ///
  /// This is in the same order as [urls]. If this was constructed using
  /// [SourcemapSingle.from_entries], this contains files from any [FileLocation]s
  /// used to build the mapping. If it was parsed from JSON, it contains files
  /// for any sources whose contents were provided via the `"sourcesContent"`
  /// field.
  ///
  /// Files whose contents aren't available are `null`.
  final List<SourceFile?> files;

  /// Entries indicating the beginning of each span.
  final List<TargetLineEntry> lines;

  /// Url of the target file.
  String? targetUrl;

  /// Source root prepended to all entries in [urls].
  String? source_root;

  final Uri? _map_url;

  final Map<String, dynamic> extensions;

  SourcemapSingle._(
    final this.targetUrl,
    final this.files,
    final this.urls,
    final this.names,
    final this.lines,
  )   : _map_url = null,
        extensions = <String, dynamic>{};

  factory SourcemapSingle.from_entries(
    final Iterable<Entry> entries, [
    final String? fileUrl,
  ]) {
    // The entries needs to be sorted by the target offsets.
    final sourceEntries = entries.toList()..sort();
    final lines = <TargetLineEntry>[];
    // Indices associated with file urls that will be part of the source map. We
    // rely on map order so that `urls.keys[urls[u]] == u`
    final urls = <String, int>{};
    // Indices associated with identifiers that will be part of the source map.
    // We rely on map order so that `names.keys[names[n]] == n`
    final names = <String, int>{};
    // The file for each URL, indexed by [urls]' values.
    final files = <int, SourceFile>{};
    int? lineNum;
    late List<TargetEntry> targetEntries;
    for (final sourceEntry in sourceEntries) {
      if (lineNum == null || sourceEntry.target.line > lineNum) {
        lineNum = sourceEntry.target.line;
        targetEntries = <TargetEntry>[];
        lines.add(TargetLineEntry(lineNum, targetEntries));
      }
      final sourceUrl = sourceEntry.source.sourceUrl;
      final urlId = urls.putIfAbsent(sourceUrl == null ? '' : sourceUrl.toString(), () => urls.length);
      if (sourceEntry.source is FileLocation) {
        files.putIfAbsent(urlId, () => (sourceEntry.source as FileLocation).file);
      }
      final sourceEntryIdentifierName = sourceEntry.identifier_name;
      final srcNameId = () {
        if (sourceEntryIdentifierName == null) {
          return null;
        } else {
          return names.putIfAbsent(sourceEntryIdentifierName, () => names.length);
        }
      }();
      targetEntries.add(TargetEntry(
          sourceEntry.target.column, urlId, sourceEntry.source.line, sourceEntry.source.column, srcNameId));
    }
    return SourcemapSingle._(fileUrl, urls.values.map((final i) => files[i]).toList(), urls.keys.toList(),
        names.keys.toList(), lines);
  }

  SourcemapSingle.fromJson(
    final Map<dynamic, dynamic> map, {
    final dynamic mapUrl,
  })  : targetUrl = map['file'] as String?,
        urls = List<String>.from(map['sources'] as Iterable<dynamic>),
        names = List<String>.from((map['names'] as Iterable<dynamic>?) ?? <dynamic>[]),
        files = List.filled((map['sources'] as List<dynamic>).length, null),
        source_root = map['sourceRoot'] as String?,
        lines = <TargetLineEntry>[],
        _map_url = (() {
          if (mapUrl is String) {
            return Uri.parse(mapUrl);
          } else {
            return mapUrl as Uri?;
          }
        }()),
        extensions = <String, dynamic>{} {
    final sourcesContent = () {
      if (map['sourcesContent'] == null) {
        return const <String?>[];
      } else {
        return List<String?>.from(map['sourcesContent'] as Iterable<dynamic>);
      }
    }();
    for (int i = 0; i < urls.length && i < sourcesContent.length; i++) {
      final source = sourcesContent[i];
      if (source == null) {
        continue;
      } else {
        files[i] = SourceFile.fromString(source, url: urls[i]);
      }
    }
    int line = 0;
    int column = 0;
    int srcUrlId = 0;
    int srcLine = 0;
    int srcColumn = 0;
    int srcNameId = 0;
    final tokenizer = _MappingTokenizer(
      map['mappings'] as String,
    );
    var entries = <TargetEntry>[];
    while (tokenizer.hasTokens) {
      if (tokenizer.nextKind.isNewLine) {
        if (entries.isNotEmpty) {
          lines.add(TargetLineEntry(line, entries));
          entries = <TargetEntry>[];
        }
        line++;
        column = 0;
        tokenizer._consumeNewLine();
        continue;
      } else {
        // Decode the next entry, using the previous encountered values to
        // decode the relative values.
        //
        // We expect 1, 4, or 5 values. If present, values are expected in the
        // following order:
        //   0: the starting column in the current line of the generated file
        //   1: the id of the original source file
        //   2: the starting line in the original source
        //   3: the starting column in the original source
        //   4: the id of the original symbol name
        // The values are relative to the previous encountered values.
        if (tokenizer.nextKind.isNewSegment) throw _segmentError(0, line);
        column += tokenizer._consumeValue();
        if (!tokenizer.nextKind.isValue) {
          entries.add(TargetEntry(column));
        } else {
          srcUrlId += tokenizer._consumeValue();
          if (srcUrlId >= urls.length) {
            throw StateError('Invalid source url id. $targetUrl, $line, $srcUrlId');
          }
          if (!tokenizer.nextKind.isValue) throw _segmentError(2, line);
          srcLine += tokenizer._consumeValue();
          if (!tokenizer.nextKind.isValue) throw _segmentError(3, line);
          srcColumn += tokenizer._consumeValue();
          if (!tokenizer.nextKind.isValue) {
            entries.add(TargetEntry(column, srcUrlId, srcLine, srcColumn));
          } else {
            srcNameId += tokenizer._consumeValue();
            if (srcNameId >= names.length) {
              throw StateError('Invalid name id: $targetUrl, $line, $srcNameId');
            }
            entries.add(TargetEntry(column, srcUrlId, srcLine, srcColumn, srcNameId));
          }
        }
        if (tokenizer.nextKind.isNewSegment) tokenizer._consumeNewSegment();
      }
    }
    if (entries.isNotEmpty) {
      lines.add(TargetLineEntry(line, entries));
    }
    map.forEach(
      (final dynamic name, final dynamic value) {
        if (name is String) {
          if (name.startsWith('x_')) {
            extensions[name] = value;
          }
        } else {
          throw Exception("Invalid map key " + name.toString());
        }
      },
    );
  }

  /// Encodes the Mapping mappings as a json map.
  ///
  /// If [includeSourceContents] is `true`, this includes the source file
  /// contents from [files] in the map if possible.
  Map<dynamic, dynamic> toJson({
    final bool includeSourceContents = false,
  }) {
    final buff = StringBuffer();
    int line = 0;
    int column = 0;
    int srcLine = 0;
    int srcColumn = 0;
    int srcUrlId = 0;
    int srcNameId = 0;
    bool first = true;
    for (final entry in lines) {
      final nextLine = entry.line;
      if (nextLine > line) {
        for (var i = line; i < nextLine; ++i) {
          buff.write(';');
        }
        line = nextLine;
        column = 0;
        first = true;
      }
      for (final segment in entry.entries) {
        if (!first) buff.write(',');
        first = false;
        column = _append(buff, column, segment.column);
        // Encoding can be just the column offset if there is no source
        // information.
        final newUrlId = segment.sourceUrlId;
        if (newUrlId == null) {
          continue;
        }
        srcUrlId = _append(buff, srcUrlId, newUrlId);
        srcLine = _append(buff, srcLine, segment.sourceLine!);
        srcColumn = _append(buff, srcColumn, segment.sourceColumn!);
        if (segment.sourceNameId == null) {
          continue;
        }
        srcNameId = _append(buff, srcNameId, segment.sourceNameId!);
      }
    }
    final result = {
      'version': 3,
      'sourceRoot': source_root ?? '',
      'sources': urls,
      'names': names,
      'mappings': buff.toString()
    };
    if (targetUrl != null) {
      result['file'] = targetUrl!;
    }
    if (includeSourceContents) {
      result['sourcesContent'] = files.map((final file) => file?.getText(0)).toList();
    }
    extensions.forEach(
      (final name, final dynamic value) => result[name] = value as Object,
    );
    return result;
  }

  /// Appends to [buff] a VLQ encoding of [newValue] using the difference
  /// between [oldValue] and [newValue]
  static int _append(
    final StringBuffer buff,
    final int oldValue,
    final int newValue,
  ) {
    buff.writeAll(Vlq.encodeVlq(newValue - oldValue));
    return newValue;
  }

  StateError _segmentError(
    final int seen,
    final int line,
  ) =>
      StateError(
        'Invalid entry in sourcemap, expected 1, 4, or 5'
        ' values, but got $seen.\ntargeturl: $targetUrl, line: $line',
      );

  /// Returns [TargetLineEntry] which includes the location in the target [line]
  /// number. In particular, the resulting entry is the last entry whose line
  /// number is lower or equal to [line].
  // TODO bad, don't look for line here.
  TargetLineEntry? _findLine(final int line) {
    final index = binarySearch(lines)((final e) => e.line > line);
    if (index <= 0) {
      return null;
    } else {
      return lines[index - 1];
    }
  }

  /// Returns [TargetEntry] which includes the location denoted by
  /// [line], [column]. If [lineEntry] corresponds to [line], then this will be
  /// the last entry whose column is lower or equal than [column]. If
  /// [lineEntry] corresponds to a line prior to [line], then the result will be
  /// the very last entry on that line.
  // TODO bad, don't look for column here.
  TargetEntry? _findColumn(
    final int line,
    final int column,
    final TargetLineEntry? lineEntry,
  ) {
    if (lineEntry == null || lineEntry.entries.isEmpty) {
      return null;
    } else if (lineEntry.line != line) {
      return lineEntry.entries.last;
    } else {
      final entries = lineEntry.entries;
      final index = binarySearch(entries)((final e) => e.column > column);
      if (index <= 0) {
        return null;
      } else {
        return entries[index - 1];
      }
    }
  }

  @override
  SourcemapSpan? span_for(
    final int line,
    final int column, {
    final Map<String, SourceFile>? files,
    final String? uri,
  }) {
    final entry = _findColumn(
      line,
      column,
      _findLine(line),
    );
    if (entry == null) {
      return null;
    } else {
      final sourceUrlId = entry.sourceUrlId;
      if (sourceUrlId == null) {
        return null;
      } else {
        var url = urls[sourceUrlId];
        if (source_root != null) {
          url = source_root.toString() + url;
        }
        final sourceNameId = entry.sourceNameId;
        final file = files?[url];
        if (file != null) {
          final start = file.getOffset(
            entry.sourceLine!,
            entry.sourceColumn,
          );
          if (sourceNameId != null) {
            final text = names[sourceNameId];
            final span = file.span(start, start + text.length);
            return SourcemapSpanImpl(
              span.start,
              span.end,
              span.text,
              true,
            );
          } else {
            final span = file.location(start).pointSpan();
            return SourcemapSpanImpl(
              span.start,
              span.end,
              span.text,
              false,
            );
          }
        } else {
          final start = SourceLocation(
            0,
            sourceUrl: _map_url?.resolve(url) ?? url,
            line: entry.sourceLine,
            column: entry.sourceColumn,
          );
          // Offset and other context is not available.
          if (sourceNameId != null) {
            final text = names[sourceNameId];
            return SourcemapSpanImpl(
              start,
              SourceLocation(
                start.offset + text.length,
                sourceUrl: start.sourceUrl,
                line: start.line,
                column: start.column + text.length,
              ),
              text,
              true,
            );
          } else {
            return SourcemapSpanImpl(
              start,
              start,
              '',
              false,
            );
          }
        }
      }
    }
  }

  @override
  String toString() {
    return (StringBuffer('$runtimeType : [')
          ..write('targetUrl: ')
          ..write(targetUrl)
          ..write(', sourceRoot: ')
          ..write(source_root)
          ..write(', urls: ')
          ..write(urls)
          ..write(', names: ')
          ..write(names)
          ..write(', lines: ')
          ..write(lines)
          ..write(']'))
        .toString();
  }

  String get debugString {
    final buff = StringBuffer();
    for (final lineEntry in lines) {
      final line = lineEntry.line;
      for (final entry in lineEntry.entries) {
        buff
          ..write(targetUrl)
          ..write(': ')
          ..write(line)
          ..write(':')
          ..write(entry.column);
        final sourceUrlId = entry.sourceUrlId;
        if (sourceUrlId != null) {
          buff
            ..write('   -->   ')
            ..write(source_root)
            ..write(urls[sourceUrlId])
            ..write(': ')
            ..write(entry.sourceLine)
            ..write(':')
            ..write(entry.sourceColumn);
        }
        final sourceNameId = entry.sourceNameId;
        if (sourceNameId != null) {
          buff
            ..write(' (')
            ..write(names[sourceNameId])
            ..write(')');
        }
        buff.write('\n');
      }
    }
    return buff.toString();
  }

  @override
  R match<R>({
    required final R Function(SourcemapMultisection) multi,
    required final R Function(SourcemapBundle) bundle,
    required final R Function(SourcemapSingle) single,
  }) =>
      single(this);
}

/// A line entry read from a source map.
class TargetLineEntry {
  final int line;
  final List<TargetEntry> entries;

  const TargetLineEntry(
    final this.line,
    final this.entries,
  );
}

/// A target segment entry read from a source map
class TargetEntry {
  final int column;
  final int? sourceUrlId;
  final int? sourceLine;
  final int? sourceColumn;
  final int? sourceNameId;

  const TargetEntry(
    final this.column, [
    final this.sourceUrlId,
    final this.sourceLine,
    final this.sourceColumn,
    final this.sourceNameId,
  ]);
}

/// A character iterator over a string that can peek one character ahead.
class _MappingTokenizer implements Iterator<String> {
  final String internal;
  final int _length;
  int index = -1;

  _MappingTokenizer(
    final this.internal,
  ) : _length = internal.length;

  // Iterator API is used by decodeVlq to consume VLQ entries.
  @override
  bool moveNext() => ++index < _length;

  @override
  String get current {
    if (index >= 0 && index < _length) {
      return internal[index];
    } else {
      return throw RangeError.index(index, internal);
    }
  }

  bool get hasTokens => index < _length - 1 && _length > 0;

  _TokenKind get nextKind {
    if (!hasTokens) {
      return _TokenKind.eof;
    } else {
      final next = internal[index + 1];
      if (next == ';') {
        return _TokenKind.line;
      } else if (next == ',') {
        return _TokenKind.segment;
      } else {
        return _TokenKind.value;
      }
    }
  }

  int _consumeValue() => Vlq.decodeVlq(this);

  void _consumeNewLine() {
    ++index;
  }

  void _consumeNewSegment() {
    ++index;
  }

  // Print the state of the iterator, with colors indicating the current
  // position.
  @override
  String toString() {
    final buff = StringBuffer();
    for (var i = 0; i < index; i++) {
      buff.write(internal[i]);
    }
    buff.write('[31m');
    buff.write(current);
    buff.write('[0m');
    for (var i = index + 1; i < internal.length; i++) {
      buff.write(internal[i]);
    }
    buff.write(' ($index)');
    return buff.toString();
  }
}

class _TokenKind {
  static const _TokenKind line = _TokenKind(isNewLine: true);
  static const _TokenKind segment = _TokenKind(isNewSegment: true);
  static const _TokenKind eof = _TokenKind(isEof: true);
  static const _TokenKind value = _TokenKind();
  final bool isNewLine;
  final bool isNewSegment;
  final bool isEof;

  const _TokenKind({
    final this.isNewLine = false,
    final this.isNewSegment = false,
    final this.isEof = false,
  });

  bool get isValue => !isNewLine && !isNewSegment && !isEof;
}

/// Utilities to encode and decode VLQ values used in source maps.
///
/// Sourcemaps are encoded with variable length numbers as base64 encoded
/// strings with the least significant digit coming first. Each base64 digit
/// encodes a 5-bit value (0-31) and a continuation bit. Signed values can be
/// represented by using the least significant bit of the value as the sign bit.
///
/// For more details see the source map [version 3 documentation](https://docs.google.com/document/d/1U1RGAehQwRypUTovF1KRlpiOFze0b-_2gc6fAH0KY0k/edit?usp=sharing).
abstract class Vlq {
  /// Creates the VLQ encoding of [value] as a sequence of characters
  static Iterable<String> encodeVlq(
    int value,
  ) {
    if (value < _minInt32 || value > _maxInt32) {
      throw ArgumentError('expected 32 bit int, got: $value');
    } else {
      final res = <String>[];
      var signBit = 0;
      if (value < 0) {
        signBit = 1;
        // ignore: parameter_assignments
        value = -value;
      }
      // ignore: parameter_assignments
      value = (value << 1) | signBit;
      do {
        var digit = value & _vlqBaseMask;
        // ignore: parameter_assignments
        value >>= _vlqBaseShift;
        if (value > 0) {
          digit |= _vlqContinuationBit;
        }
        res.add(_base64Digits[digit]);
      } while (value > 0);
      return res;
    }
  }

  /// Decodes a value written as a sequence of VLQ characters. The first input
  /// character will be `chars.current` after calling `chars.moveNext` once. The
  /// iterator is advanced until a stop character is found (a character without
  /// the [_vlqContinuationBit]).
  static int decodeVlq(
    final Iterator<String> chars,
  ) {
    var result = 0;
    var stop = false;
    var shift = 0;
    while (!stop) {
      if (!chars.moveNext()) throw StateError('incomplete VLQ value');
      final char = chars.current;
      var digit = _digits[char];
      if (digit == null) {
        throw FormatException('invalid character in VLQ encoding: $char');
      } else {
        stop = (digit & _vlqContinuationBit) == 0;
        digit &= _vlqBaseMask;
        result += digit << shift;
        shift += _vlqBaseShift;
      }
    }
    // Result uses the least significant bit as a sign bit. We convert it into a
    // two-complement value. For example,
    //   2 (10 binary) becomes 1
    //   3 (11 binary) becomes -1
    //   4 (100 binary) becomes 2
    //   5 (101 binary) becomes -2
    //   6 (110 binary) becomes 3
    //   7 (111 binary) becomes -3
    final negate = (result & 1) == 1;
    result = result >> 1;
    result = negate ? -result : result;
    // TODO(sigmund): can we detect this earlier?
    if (result < _minInt32 || result > _maxInt32) {
      throw FormatException('expected an encoded 32 bit int, but we got: $result');
    } else {
      return result;
    }
  }

  static const int _vlqBaseShift = 5;
  static const int _vlqBaseMask = (1 << 5) - 1;
  static const int _vlqContinuationBit = 1 << 5;
  static const String _base64Digits = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
  static final Map<String, int> _digits = () {
    final map = <String, int>{};
    for (var i = 0; i < 64; i++) {
      map[_base64Digits[i]] = i;
    }
    return map;
  }();
  static final int _maxInt32 = (pow(2, 31) as int) - 1;
  static final int _minInt32 = -(pow(2, 31) as int);
}

/// Find the first entry in a sorted [list] that matches a monotonic predicate.
/// Given a result `n`, that all items before `n` will not match, `n` matches,
/// and all items after `n` match too. The result is -1 when there are no
/// items, 0 when all items match, and list.length when none does.
int Function(
  bool Function(T),
) binarySearch<T>(
  final List<T> list,
) =>
    (final matches) {
      if (list.isEmpty) {
        return -1;
      } else if (matches(list.first)) {
        return 0;
      } else if (!matches(list.last)) {
        return list.length;
      } else {
        var min = 0;
        var max = list.length - 1;
        while (min < max) {
          final half = min + ((max - min) ~/ 2);
          if (matches(list[half])) {
            max = half;
          } else {
            min = half + 1;
          }
        }
        return max;
      }
    };
