import 'sourcemap.dart';

/// Builds a source map given a set of mappings.
abstract class SourcemapBuilder {
  /// Adds an entry mapping [target] to [source].
  ///
  /// If [source] is a [SourcemapSpan] with
  /// `isIdentifier` set to true, this entry is considered to represent an
  /// identifier whose value will be stored in the source map.
  void add_span({
    required final SourcemapSpan source,
    required final SourcemapSpan target,
  });

  /// Adds an entry mapping [target] to [source].
  void add_location(
    final SourcemapLocation source,
    final SourcemapLocation target,
    final String? identifier,
  );

  /// Build this builder to a sourcemap.
  SourcemapSingle build({
    required final String file_url,
  });
}

/// An entry in the source map builder.
abstract class SourcemapBuilderEntry {
  /// Span denoting the original location in the input source file
  SourcemapLocation get source;

  /// Span indicating the corresponding location in the target file.
  SourcemapLocation get target;

  /// An identifier name, when this location is the start of an identifier.
  String? get identifier_name;
}

SourcemapSingle build_sourcemap({
  required final List<SourcemapBuilderEntry> entries,
  required final String file_url,
}) {
  final builder = SourcemapBuilderImpl();
  for (final e in entries) {
    builder.add_entry(e);
  }
  return builder.build(
    file_url: file_url,
  );
}

class SourcemapBuilderImpl implements SourcemapBuilder {
  final List<SourcemapBuilderEntry> _entries;

  SourcemapBuilderImpl() : _entries = [];

  void add_entry(
    final SourcemapBuilderEntry e,
  ) {
    _entries.add(e);
  }

  @override
  void add_span({
    required final SourcemapSpan source,
    required final SourcemapSpan target,
  }) {
    _entries.add(
      SourcemapBuilderEntryImpl(
        source: source.start,
        target: target.start,
        identifier_name: () {
          if (source.is_identifier) {
            return source.text;
          } else {
            return null;
          }
        }(),
      ),
    );
  }

  @override
  void add_location(
    final SourcemapLocation source,
    final SourcemapLocation target,
    final String? identifier,
  ) {
    _entries.add(
      SourcemapBuilderEntryImpl(
        source: source,
        target: target,
        identifier_name: identifier,
      ),
    );
  }

  @override
  SourcemapSingle build({
    required final String file_url,
  }) {
    // The entries needs to be sorted by the target offsets.
    final source_entries = _entries.toList()
      ..sort(
        (final a, final b) {
          final res = a.target.offset.compareTo(
            b.target.offset,
          );
          if (res != 0) {
            return res;
          } else {
            final _res = a.source.sourceUrl.toString().compareTo(
                  b.source.sourceUrl.toString(),
                );
            if (_res != 0) {
              return _res;
            } else {
              return a.source.offset.compareTo(
                b.source.offset,
              );
            }
          }
        },
      );
    final lines = <SourcemapTargetLineEntry>[];
    // Indices associated with file urls that will be part of the source map. We
    // rely on map order so that `urls.keys[urls[u]] == u`
    final urls = <String, int>{};
    // Indices associated with identifiers that will be part of the source map.
    // We rely on map order so that `names.keys[names[n]] == n`
    final names = <String, int>{};
    // The file for each URL, indexed by [urls]' values.
    final files = <int, SourcemapFile>{};
    int line_num = -1;
    List<SourcemapTargetEntry> target_entries = [];
    for (final source_entry in source_entries) {
      if (source_entry.target.line > line_num) {
        line_num = source_entry.target.line;
        target_entries = <SourcemapTargetEntry>[];
        lines.add(
          SourcemapTargetLineEntryImpl(
            line: line_num,
            entries: target_entries,
          ),
        );
      }
      final url_id = urls.putIfAbsent(
        () {
          final source_url = source_entry.source.sourceUrl;
          if (source_url == null) {
            return '';
          } else {
            return source_url.toString();
          }
        }(),
        () => urls.length,
      );
      final s = source_entry.source;
      final file = s.file;
      if (file != null) {
        files.putIfAbsent(
          url_id,
          () => file,
        );
      }
      target_entries.add(
        SourcemapTargetEntryImpl(
          column: source_entry.target.column,
          source_url_id: url_id,
          source_line: source_entry.source.line,
          source_column: source_entry.source.column,
          source_name_id: () {
            final source_entry_identifier_name = source_entry.identifier_name;
            if (source_entry_identifier_name == null) {
              return null;
            } else {
              return names.putIfAbsent(
                source_entry_identifier_name,
                () => names.length,
              );
            }
          }(),
        ),
      );
    }
    return SourcemapSingleImpl(
      target_url: file_url,
      files: urls.values.map((final i) => files[i]).toList(),
      urls: urls.keys.toList(),
      names: names.keys.toList(),
      lines: lines,
      map_url: null,
      extensions: <String, Object>{},
      source_root: null,
    );
  }
}

class SourcemapBuilderEntryImpl implements SourcemapBuilderEntry {
  @override
  final SourcemapLocation source;
  @override
  final SourcemapLocation target;
  @override
  final String? identifier_name;

  const SourcemapBuilderEntryImpl({
    required this.source,
    required this.target,
    required this.identifier_name,
  });
}
