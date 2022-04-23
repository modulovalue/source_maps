// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// TODO remove this dependency.
import 'package:source_span/source_span.dart';

import 'parser.dart';
import 'source_map_span.dart';

/// Builds a source map given a set of mappings.
abstract class SourceMapBuilder {
  /// Adds an entry mapping [target] to [source].
  ///
  /// If [source] is a [SourcemapSpan] with
  /// `isIdentifier` set to true, this entry is considered to represent an
  /// identifier whose value will be stored in the source map.
  void add_span(
    final SourcemapSpan source,
    final SourcemapSpan target,
  );

  /// Adds an entry mapping [target] to [source].
  void add_location(
      // TODO don't depend on source_span.
    final SourceLocation source,
      // TODO don't depend on source_span.
    final SourceLocation target,
    final String? identifier,
  );

  SourcemapSingle build(
    final String file_url,
  );
}

/// An entry in the source map builder.
abstract class Entry implements Comparable<Entry> {
  /// Span denoting the original location in the input source file
  // TODO don't depend on source_span.
  SourceLocation get source;

  /// Span indicating the corresponding location in the target file.
  // TODO don't depend on source_span.
  SourceLocation get target;

  /// An identifier name, when this location is the start of an identifier.
  String? get identifier_name;
}

class SourceMapBuilderImpl implements SourceMapBuilder {
  final List<Entry> _entries;

  SourceMapBuilderImpl() : _entries = [];

  @override
  void add_span(
    final SourcemapSpan source,
    final SourcemapSpan target,
  ) {
    _entries.add(
      EntryImpl(
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
      // TODO don't depend on source_span.
    final SourceLocation source,
      // TODO don't depend on source_span.
    final SourceLocation target,
    final String? identifier,
  ) {
    _entries.add(
      EntryImpl(
        source: source,
        target: target,
        identifier_name: identifier,
      ),
    );
  }

  @override
  SourcemapSingle build(
    final String file_url,
  ) =>
      SourcemapSingle.from_entries(
        _entries,
        file_url,
      );
}

/// An entry in the source map builder.
class EntryImpl implements Entry {
  @override
  final SourceLocation source;
  @override
  final SourceLocation target;
  @override
  final String? identifier_name;

  const EntryImpl({
    required this.source,
    required this.target,
    required this.identifier_name,
  });

  @override
  int compareTo(
    final Entry other,
  ) {
    int res = target.compareTo(
      other.target,
    );
    if (res != 0) {
      return res;
    } else {
      res = source.sourceUrl.toString().compareTo(
            other.source.sourceUrl.toString(),
          );
      if (res != 0) {
        return res;
      } else {
        return source.compareTo(
          other.source,
        );
      }
    }
  }
}
