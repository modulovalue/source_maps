import 'package:source_span/source_span.dart';

import 'sourcemap.dart';

/// Returns the span associated with [line] and [column].
///
/// [uri] is the optional location of the output file to find the span for
/// to disambiguate cases where a mapping may have different mappings for
/// different output files.
SourcemapSpan? span_for_sourcemap({
  required final Sourcemap sourcemap,
  required final int line,
  required final int column,
  required final Map<String, SourcemapFile>? files,
  required final String? uri,
}) {
  return sourcemap.match(
    multi: (final sourcemap) {
      int _index_for(
        final int line,
        final int column,
      ) {
        for (int i = 0; i < sourcemap.lineStart.length; i++) {
          if (line < sourcemap.lineStart[i]) {
            return i - 1;
          } else {
            if (line == sourcemap.lineStart[i] && column < sourcemap.columnStart[i]) {
              return i - 1;
            } else {
              // Continue.
            }
          }
        }
        return sourcemap.lineStart.length - 1;
      }

      final index = _index_for(line, column);
      return span_for_sourcemap(
        sourcemap: sourcemap.maps[index],
        line: line - sourcemap.lineStart[index],
        column: column - sourcemap.columnStart[index],
        files: files,
        uri: null,
      );
    },
    bundle: (final sourcemap) {
      // Uri can't be null for collections.
      uri!;
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
          final candidateMapping = sourcemap.mappings[candidate];
          if (candidateMapping != null) {
            return span_for_sourcemap(
              sourcemap: candidateMapping,
              line: line,
              column: column,
              files: files,
              uri: candidate,
            );
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
      final location = SourcemapLocationImpl(
        offset: offset,
        line: line,
        column: column,
        sourceUrl: Uri.parse(uri),
        file: null,
      );
      return SourcemapSpanImpl(
        start: location,
        end: location,
        text: '',
        is_identifier: false,
        sourceUrl: location.sourceUrl,
      );
    },
    single: (final sourcemap) {
      // Returns [SourcemapTargetLineEntry] which includes the location in the target [line]
      // number. In particular, the resulting entry is the last entry whose line
      // number is lower or equal to [line].
      // TODO bad, don't look for line here.
      SourcemapTargetLineEntry? _find_line(final int line) {
        final index = binary_search(sourcemap.lines)((final e) => e.line > line);
        if (index <= 0) {
          return null;
        } else {
          return sourcemap.lines[index - 1];
        }
      }

      // Returns [SourcemapTargetEntry] which includes the location denoted by
      // [line], [column]. If [lineEntry] corresponds to [line], then this will be
      // the last entry whose column is lower or equal than [column]. If
      // [lineEntry] corresponds to a line prior to [line], then the result will be
      // the very last entry on that line.
      // TODO bad, don't look for column here.
      SourcemapTargetEntry? _find_column(
        final int line,
        final int column,
        final SourcemapTargetLineEntry? lineEntry,
      ) {
        if (lineEntry == null || lineEntry.entries.isEmpty) {
          return null;
        } else if (lineEntry.line != line) {
          return lineEntry.entries.last;
        } else {
          final entries = lineEntry.entries;
          final index = binary_search(entries)((final e) => e.column > column);
          if (index <= 0) {
            return null;
          } else {
            return entries[index - 1];
          }
        }
      }

      final entry = _find_column(
        line,
        column,
        _find_line(line),
      );
      if (entry == null) {
        return null;
      } else {
        final sourceUrlId = entry.source_url_id;
        if (sourceUrlId == null) {
          return null;
        } else {
          String url = sourcemap.urls[sourceUrlId];
          if (sourcemap.source_root != null) {
            url = sourcemap.source_root.toString() + url;
          }
          final sourceNameId = entry.source_name_id;
          final file = files?[url];
          if (file != null) {
            final start = SourceFile.fromString(
              file.content,
              url: file.url,
            ).getOffset(
              entry.source_line!,
              entry.source_column,
            );
            if (sourceNameId != null) {
              final text = sourcemap.names[sourceNameId];
              final end = start + text.length;
              final span = SourceFile.fromString(
                file.content,
                url: file.url,
              ).span(
                start,
                end,
              );
              return SourcemapSpanImpl(
                start: SourcemapLocationImpl(
                  offset: start,
                  line: span.start.line,
                  column: span.start.column,
                  sourceUrl: file.url,
                  file: file,
                ),
                end: SourcemapLocationImpl(
                  offset: end,
                  line: span.end.line,
                  column: span.end.column,
                  sourceUrl: file.url,
                  file: file,
                ),
                text: text,
                sourceUrl: file.url,
                is_identifier: true,
              );
            } else {
              final span = SourceFile.fromString(
                file.content,
                url: file.url,
              ).location(
                start,
              );
              return SourcemapSpanImpl(
                start: SourcemapLocationImpl(
                  offset: start,
                  line: span.line,
                  column: span.column,
                  sourceUrl: file.url,
                  file: file,
                ),
                end: SourcemapLocationImpl(
                  offset: start,
                  line: span.line,
                  column: span.column,
                  sourceUrl: file.url,
                  file: file,
                ),
                text: "",
                sourceUrl: file.url,
                is_identifier: false,
              );
            }
          } else {
            final start = SourcemapLocationImpl(
              offset: 0,
              sourceUrl: sourcemap.map_url?.resolve(url) ?? Uri.tryParse(url),
              line: entry.source_line ?? 0,
              column: entry.source_column ?? 0,
              file: null,
            );
            // Offset and other context is not available.
            if (sourceNameId != null) {
              final text = sourcemap.names[sourceNameId];
              return SourcemapSpanImpl(
                start: start,
                end: SourcemapLocationImpl(
                  offset: start.offset + text.length,
                  sourceUrl: start.sourceUrl,
                  line: start.line,
                  column: start.column + text.length,
                  file: null,
                ),
                text: text,
                is_identifier: true,
                sourceUrl: start.sourceUrl,
              );
            } else {
              return SourcemapSpanImpl(
                start: start,
                end: start,
                text: '',
                is_identifier: false,
                sourceUrl: start.sourceUrl,
              );
            }
          }
        }
      }
    },
  );
}

/// The result is -1 when there are no
/// items, 0 when all items match, and
/// list.length when none does.
// @visibleForTesting
int Function(
  bool Function(T),
) binary_search<T>(
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
        int min = 0;
        int max = list.length - 1;
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
