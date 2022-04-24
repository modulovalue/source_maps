import 'dart:convert';

/// Attempts to extract a sourcemap comment from the given lines.
///
/// It is assumed that the sourcemap comment is on the last line
/// or on the second to last line if the last line is empty.
SourcemapComment extract_sourcemap_comment({
  required final List<String> lines,
}) {
  final last_line = lines.last;
  if (last_line.trim().isEmpty) {
    final sourcemap_comment_line = lines[lines.length - 2];
    return parse_sourcemap_comment(
      line: sourcemap_comment_line,
    );
  } else {
    return parse_sourcemap_comment(
      line: last_line,
    );
  }
}

/// Attempts to extract a sourcemap comment from the given line.
SourcemapComment parse_sourcemap_comment({
  required final String line,
}) {
  if (line.isEmpty) {
    return const SourcemapCommentInvalidImpl(
      reason: "The given line is empty.",
    );
  } else {
    final lines = LineSplitter.split(line);
    final sourcemap_coment_line = lines.first;
    const indicator = "//# sourceMappingURL=";
    if (sourcemap_coment_line.startsWith(indicator)) {
      final data_part = sourcemap_coment_line.substring(
        indicator.length,
      );
      final uri = Uri.tryParse(data_part);
      if (uri == null) {
        return const SourcemapCommentInvalidImpl(
          reason: "A source map comment was detected but its uri "
              "could not be parsed successfully into an Uri object.",
        );
      } else {
        final data_component = uri.data;
        if (data_component == null) {
          return SourcemapCommentPathImpl(
            path: uri,
          );
        } else {
          return SourcemapCommentInlineImpl(
            data: data_component,
          );
        }
      }
    } else {
      return const SourcemapCommentInvalidImpl(
        reason: "The given line does not start with " + indicator,
      );
    }
  }
}

abstract class SourcemapComment {
  Z match<Z>({
    required final Z Function(SourcemapCommentInline) inline,
    required final Z Function(SourcemapCommentPath) path,
    required final Z Function(SourcemapCommentInvalid) invalid,
  });
}

abstract class SourcemapCommentInline implements SourcemapComment {
  UriData get data;
}

abstract class SourcemapCommentPath implements SourcemapComment {
  Uri get path;
}

abstract class SourcemapCommentInvalid implements SourcemapComment {
  String get reason;
}

class SourcemapCommentInlineImpl implements SourcemapCommentInline {
  @override
  final UriData data;

  const SourcemapCommentInlineImpl({
    required final this.data,
  });

  @override
  Z match<Z>({
    required final Z Function(SourcemapCommentInline) inline,
    required final Z Function(SourcemapCommentPath) path,
    required final Z Function(SourcemapCommentInvalid) invalid,
  }) =>
      inline(this);

  @override
  String toString() => 'SourcemapCommentInlineImpl{data: $data}';
}

class SourcemapCommentPathImpl implements SourcemapCommentPath {
  @override
  final Uri path;

  const SourcemapCommentPathImpl({
    required final this.path,
  });

  @override
  Z match<Z>({
    required final Z Function(SourcemapCommentInline) inline,
    required final Z Function(SourcemapCommentPath) path,
    required final Z Function(SourcemapCommentInvalid) invalid,
  }) =>
      path(this);

  @override
  String toString() => 'SourcemapCommentPathImpl{path: $path}';
}

class SourcemapCommentInvalidImpl implements SourcemapCommentInvalid {
  @override
  final String reason;

  const SourcemapCommentInvalidImpl({
    required final this.reason,
  });

  @override
  Z match<Z>({
    required final Z Function(SourcemapCommentInline) inline,
    required final Z Function(SourcemapCommentPath) path,
    required final Z Function(SourcemapCommentInvalid) invalid,
  }) =>
      invalid(this);

  @override
  String toString() => 'SourcemapCommentInvalidImpl{reason: $reason}';
}
