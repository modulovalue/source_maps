// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// TODO remove this dependency.
import 'package:source_span/source_span.dart';

abstract class SourcemapSpan {
  /// Whether this span represents an identifier.
  ///
  /// If this is `true`, [text] is the value of the identifier.
  bool get is_identifier;

  /// The start location of this span.
  // TODO don't depend on source_span.
  SourceLocation get start;

  /// The end location of this span, exclusive.
  // TODO don't depend on source_span.
  SourceLocation get end;

  /// The source text for this span.
  String get text;

  /// The URL of the source (typically a file) of this span.
  ///
  /// This may be null, indicating that the source URL is unknown or
  /// unavailable.
  Uri? get sourceUrl;
}

// ignore: prefer_mixin
class SourcemapSpanImpl implements SourcemapSpan {
  @override
  // TODO don't depend on source_span.
  final SourceLocation end;
  @override
  // TODO don't depend on source_span.
  final SourceLocation start;
  @override
  final String text;
  @override
  final bool is_identifier;

  const SourcemapSpanImpl(
    final this.start,
    final this.end,
    final this.text,
    final this.is_identifier,
  );

  @override
  Uri? get sourceUrl => start.sourceUrl;
}
