import 'package:source_span/source_span.dart' show SourceFile;

import 'sourcemap.dart';

class SourcemapTextbufferSourcespanImpl implements SourcemapTextbuffer {
  const SourcemapTextbufferSourcespanImpl();

  // TODO these operate on lines and lines are available where this is used used. Use those lines.
  @override
  int calculate_index({
    required final SourcemapFile file,
    required final int line,
    required final int column,
  }) {
    return SourceFile.fromString(
      file.content,
      url: file.url,
    ).getOffset(
      line,
      column,
    );
  }

  // TODO these operate on lines and lines are available where this is used used. Use those lines.
  @override
  R calculate_location<R>({
    required final SourcemapFile file,
    required final int offset,
    required final R Function(int column, int line) make,
  }) {
    final f = SourceFile.fromString(
      file.content,
      url: file.url,
    ).location(
      offset,
    );
    return make(
      f.column,
      f.line,
    );
  }

  @override
  SourcemapTargetEntry? find({
    required final List<SourcemapTargetLineEntry> lines,
    required final int line,
    required final int column,
  }) {
    T? Function(
      bool Function(T),
    ) binary_search<T extends Object>(
      final List<T> list,
    ) =>
        (final matches) {
          if (list.isEmpty) {
            return null;
          } else if (matches(list.first)) {
            return list.first;
          } else if (!matches(list.last)) {
            return list.last;
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
            return list[max - 1];
          }
        };

    // Returns [SourcemapTargetLineEntry] which includes the location in the target [line]
    // number. In particular, the resulting entry is the last entry whose line
    // number is lower or equal to [line].
    final found_line = binary_search(
      lines,
    )(
      (final e) => e.line > line,
    );
    // Returns [SourcemapTargetEntry] which includes the location denoted by
    // [line], [column]. If [lineEntry] corresponds to [line], then this will be
    // the last entry whose column is lower or equal than [column]. If
    // [lineEntry] corresponds to a line prior to [line], then the result will be
    // the very last entry on that line.
    if (found_line == null) {
      return null;
    } else if (found_line.entries.isEmpty) {
      return null;
    } else if (found_line.line != line) {
      return found_line.entries.last;
    } else {
      return binary_search(
        found_line.entries,
      )(
        (final e) => e.column > column,
      );
    }
  }
}
