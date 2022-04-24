// ignore_for_file: invariant_booleans

import 'sourcemap.dart';
import 'vlq.dart';

/// Parses a source map or source map bundle.
///
/// [source_map_file_url] indicates the URL of the source map
/// file itself. If it's passed, any URLs in the source
/// map will be interpreted as relative to this URL
/// when generating spans.
Sourcemap sourcemap_from_json({
  required final dynamic json,
  required final Uri? source_map_file_url,
}) {
  // TODO(tjblasi): Ignore the first line of [jsonMap] if the JSON safety string `)]}'` begins the string representation of the map.
  if (json is List) {
    final sourcemap = SourcemapCollectionImpl();
    for (final map in json) {
      sourcemap.addMapping(
        sourcemap_from_json(
          json: map as Object,
          source_map_file_url: source_map_file_url,
        ) as SourcemapSingle,
      );
    }
    return sourcemap;
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
          final sections = map['sections'] as List<dynamic>;
          final lineStart = <int>[];
          final columnStart = <int>[];
          final maps = <Sourcemap>[];
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
                  lineStart.add(line);
                  columnStart.add(column);
                  final dynamic url = section['url'];
                  final dynamic map = section['map'];
                  if (url != null && map != null) {
                    throw const FormatException("section can't use both url and map entries");
                  } else if (map != null) {
                    maps.add(
                      sourcemap_from_json(
                        json: map as Object,
                        source_map_file_url: source_map_file_url,
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
          if (lineStart.isEmpty) {
            throw const FormatException(
              'expected at least one section',
            );
          } else {
            return SourcemapMultisectionImpl(
              lineStart: lineStart,
              columnStart: columnStart,
              maps: maps,
            );
          }
        }
      } else {
        final targetUrl = map['file'] as String;
        final urls = List<String>.from(map['sources'] as Iterable<dynamic>);
        final names = List<String>.from((map['names'] as Iterable<dynamic>?) ?? <dynamic>[]);
        final files = List<String?>.filled(urls.length, null);
        final source_root = map['sourceRoot'] as String?;
        final lines = <SourcemapTargetLineEntry>[];
        final _map_url = source_map_file_url;
        final extensions = <String, Object>{};
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
            files[i] = source;
          }
        }
        StateError _segmentError(
          final int seen,
          final int line,
        ) =>
            StateError(
              'Invalid entry in sourcemap, expected 1, 4, or 5'
              ' values, but got $seen.\ntargeturl: $targetUrl, line: $line',
            );
        int line = 0;
        int column = 0;
        int srcUrlId = 0;
        int srcLine = 0;
        int srcColumn = 0;
        int srcNameId = 0;
        final tokenizer = _VlqTokenizer(
          internal: map['mappings'] as String,
        );
        final entries = <SourcemapTargetEntry>[];
        while (tokenizer.has_tokens) {
          if (tokenizer.next_kind() == _VlqTokenKind.line) {
            if (entries.isNotEmpty) {
              lines.add(
                SourcemapTargetLineEntryImpl(
                  line: line,
                  entries: entries.toList(),
                ),
              );
              entries.clear();
            }
            line++;
            column = 0;
            tokenizer._consume();
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
            if (tokenizer.next_kind() == _VlqTokenKind.segment) {
              throw _segmentError(0, line);
            } else {
              column += Vlq.decode_vlq(tokenizer);
              if (tokenizer.next_kind() != _VlqTokenKind.value) {
                entries.add(
                  SourcemapTargetEntryImpl(
                    column: column,
                  ),
                );
              } else {
                srcUrlId += Vlq.decode_vlq(tokenizer);
                if (srcUrlId >= urls.length) {
                  throw StateError('Invalid source url id. $targetUrl, $line, $srcUrlId');
                } else {
                  if (tokenizer.next_kind() != _VlqTokenKind.value) {
                    throw _segmentError(2, line);
                  } else {
                    srcLine += Vlq.decode_vlq(tokenizer);
                    if (tokenizer.next_kind() != _VlqTokenKind.value) {
                      throw _segmentError(3, line);
                    } else {
                      srcColumn += Vlq.decode_vlq(tokenizer);
                      if (tokenizer.next_kind() != _VlqTokenKind.value) {
                        entries.add(
                          SourcemapTargetEntryImpl(
                            column: column,
                            source_url_id: srcUrlId,
                            source_line: srcLine,
                            source_column: srcColumn,
                          ),
                        );
                      } else {
                        srcNameId += Vlq.decode_vlq(tokenizer);
                        if (srcNameId >= names.length) {
                          throw StateError(
                            'Invalid name id: $targetUrl, $line, $srcNameId',
                          );
                        } else {
                          entries.add(
                            SourcemapTargetEntryImpl(
                              column: column,
                              source_url_id: srcUrlId,
                              source_line: srcLine,
                              source_column: srcColumn,
                              source_name_id: srcNameId,
                            ),
                          );
                        }
                      }
                    }
                  }
                }
              }
              if (tokenizer.next_kind() == _VlqTokenKind.segment) {
                tokenizer._consume();
              }
            }
          }
        }
        if (entries.isNotEmpty) {
          lines.add(
            SourcemapTargetLineEntryImpl(
              line: line,
              entries: entries,
            ),
          );
        }
        map.forEach(
          (final dynamic name, final Object? value) {
            if (name is String) {
              if (name.startsWith('x_')) {
                if (value != null) {
                  extensions[name] = value;
                }
              }
            } else {
              throw Exception("Invalid map key " + name.toString());
            }
          },
        );
        return SourcemapSingleImpl(
          target_url: targetUrl,
          files: files,
          urls: urls,
          names: names,
          lines: lines,
          map_url: _map_url,
          extensions: extensions,
          source_root: source_root,
        );
      }
    }
  } else {
    throw Exception("Invalid type. ${json.runtimeType}");
  }
}

/// A character iterator over a string that can peek one character ahead.
class _VlqTokenizer implements Iterator<String> {
  final String internal;
  final int _length;
  int char = -1;

  _VlqTokenizer({
    required final this.internal,
  }) : _length = internal.length;

  @override
  bool moveNext() {
    char += 1;
    return char < _length;
  }

  @override
  String get current {
    if (char >= 0 && char < _length) {
      return internal[char];
    } else {
      return throw RangeError.index(char, internal);
    }
  }

  bool get has_tokens => char < _length - 1 && _length > 0;

  _VlqTokenKind next_kind() {
    if (!has_tokens) {
      return _VlqTokenKind.eof;
    } else {
      final next = internal[char + 1];
      if (next == ';') {
        return _VlqTokenKind.line;
      } else if (next == ',') {
        return _VlqTokenKind.segment;
      } else {
        return _VlqTokenKind.value;
      }
    }
  }

  void _consume() => char += 1;
}

enum _VlqTokenKind {
  line,
  segment,
  eof,
  value,
}
