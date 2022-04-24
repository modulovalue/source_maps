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
  required final Map<String, SourcemapSpanFile>? files,
  required final String? uri,
  required final SourcemapTextbuffer textbuffer,
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
        textbuffer: textbuffer,
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
              textbuffer: textbuffer,
            );
          }
        }
        onBoundary = separatorCodeUnits.contains(uri.codeUnitAt(i));
      }
      // Note: when there is no source map for an uri, this behaves like an
      // identity function, returning the requested location as the result.
      final location = SourcemapLocationImpl(
        // Create a mock offset for the output location. We compute it in terms
        // of the input line and column to minimize the chances that two different
        // line and column locations are mapped to the same offset.
        offset: line * 1000000 + column,
        line: line,
        column: column,
      );
      return SourcemapSpanImpl(
        file: null,
        sourceUrl: Uri.parse(uri),
        start: location,
        end: location,
        text: '',
        is_identifier: false,
      );
    },
    single: (final sourcemap) {
      final found_entry = textbuffer.find(
        lines: sourcemap.lines,
        line: line,
        column: column,
      );
      if (found_entry == null) {
        return null;
      } else {
        final sourceUrlId = found_entry.source_url_id;
        if (sourceUrlId == null) {
          return null;
        } else {
          String url = sourcemap.urls[sourceUrlId];
          if (sourcemap.source_root != null) {
            url = sourcemap.source_root.toString() + url;
          }
          final sourceNameId = found_entry.source_name_id;
          final file = files?[url];
          if (file != null) {
            final start = textbuffer.calculate_index(
              file: file.content,
              line: found_entry.source_line!,
              column: found_entry.source_column ?? 0,
            );
            if (sourceNameId != null) {
              final text = sourcemap.names[sourceNameId];
              final end = start + text.length;
              return SourcemapSpanImpl(
                file: file.content,
                sourceUrl: file.url,
                start: textbuffer.calculate_location(
                  file: file.content,
                  offset: start,
                  make: (final c, final r) => SourcemapLocationImpl(
                    offset: start,
                    column: c,
                    line: r,
                  ),
                ),
                end: textbuffer.calculate_location(
                  file: file.content,
                  offset: end,
                  make: (final c, final r) => SourcemapLocationImpl(
                    offset: end,
                    column: c,
                    line: r,
                  ),
                ),
                text: text,
                is_identifier: true,
              );
            } else {
              return textbuffer.calculate_location(
                file: file.content,
                offset: start,
                make: (final c, final l) => SourcemapSpanImpl(
                  file: file.content,
                  sourceUrl: file.url,
                  start: SourcemapLocationImpl(
                    offset: start,
                    column: c,
                    line: l,
                  ),
                  end: SourcemapLocationImpl(
                    offset: start,
                    column: c,
                    line: l,
                  ),
                  text: "",
                  is_identifier: false,
                ),
              );
            }
          } else {
            final _url = sourcemap.map_url?.resolve(url) ?? Uri.tryParse(url);
            final start = SourcemapLocationImpl(
              offset: 0,
              line: found_entry.source_line ?? 0,
              column: found_entry.source_column ?? 0,
            );
            // Offset and other context is not available.
            if (sourceNameId != null) {
              final text = sourcemap.names[sourceNameId];
              return SourcemapSpanImpl(
                file: null,
                sourceUrl: _url,
                start: start,
                end: SourcemapLocationImpl(
                  offset: start.offset + text.length,
                  line: start.line,
                  column: start.column + text.length,
                ),
                text: text,
                is_identifier: true,
              );
            } else {
              return SourcemapSpanImpl(
                file: null,
                sourceUrl: _url,
                start: start,
                end: start,
                text: '',
                is_identifier: false,
              );
            }
          }
        }
      }
    },
  );
}

class SourcemapSpanFile {
  final String content;

  final Uri? url;

  const SourcemapSpanFile({
    required final this.content,
    required final this.url,
  });
}
