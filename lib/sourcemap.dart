/// A mapping parsed out of a source map.
abstract class Sourcemap {
  R match<R>({
    required final R Function(SourcemapMultisection) multi,
    required final R Function(SourcemapCollection) bundle,
    required final R Function(SourcemapSingle) single,
  });
}

/// A sourcemap containing sections.
abstract class SourcemapMultisection implements Sourcemap {
  /// For each section, the start line offset.
  List<int> get lineStart;

  /// For each section, the start column offset.
  List<int> get columnStart;

  /// For each section, the actual source map information, which is not adjusted
  /// for offsets.
  List<Sourcemap> get maps;
}

/// A map containing a collection of sourcemaps.
abstract class SourcemapCollection implements Sourcemap {
  Map<String, SourcemapSingle> get mappings;

  void addMapping(
    final SourcemapSingle mapping,
  );

  bool containsMapping(
    final String url,
  );
}

/// A map containing direct source mappings.
abstract class SourcemapSingle implements Sourcemap {
  /// Source urls used in the mapping, indexed by id.
  List<String> get urls;

  /// Source names used in the mapping, indexed by id.
  List<String> get names;

  /// The [SourcemapFile]s to which the entries in [lines] refer.
  ///
  /// Files whose contents aren't available are `null`.
  // TODO just a string for the content should be enough because urls give the url?
  List<SourcemapFile?> get files;

  /// Entries indicating the beginning of each span.
  List<SourcemapTargetLineEntry> get lines;

  /// Url of the target file.
  String get target_url;

  /// Source root prepended to all entries in [urls].
  String? get source_root;

  Uri? get map_url;

  Map<String, Object> get extensions;

  SourcemapSingle copy_with_new_source_root(
    final String new_source_root,
  );
}

/// A span of a file within a source map.
abstract class SourcemapSpan {
  /// Whether this span represents an identifier.
  ///
  /// If this is `true`, [text] is the value of the identifier.
  bool get is_identifier;

  /// The start location of this span.
  SourcemapLocationSmart get start;

  /// The end location of this span, exclusive.
  SourcemapLocationSmart get end;

  /// The source text for this span.
  String get text;

  /// The URL of the source (typically a file) of this span.
  ///
  /// This may be null, indicating that the source URL is unknown or
  /// unavailable.
  Uri? get sourceUrl;
}

/// A line entry read from a source map.
abstract class SourcemapTargetLineEntry {
  int get line;

  List<SourcemapTargetEntry> get entries;
}

/// A target segment entry read from a sourcemap
abstract class SourcemapTargetEntry {
  int get column;

  int? get source_url_id;

  int? get source_line;

  int? get source_column;

  int? get source_name_id;
}

/// A location into a source file within a sourcemap.
abstract class SourcemapLocation {
  int get offset;

  Uri? get sourceUrl;

  SourcemapFile? get file;
}

abstract class SourcemapLocationSmart implements SourcemapLocation{
  int get line;

  int get column;
}

/// A location to a source file within a sourcemap.
abstract class SourcemapFile {
  String get content;

  Uri? get url;
}

class SourcemapMultisectionImpl implements SourcemapMultisection {
  @override
  final List<int> lineStart;
  @override
  final List<int> columnStart;
  @override
  final List<Sourcemap> maps;

  SourcemapMultisectionImpl()
      : lineStart = [],
        columnStart = [],
        maps = [];

  @override
  R match<R>({
    required final R Function(SourcemapMultisection) multi,
    required final R Function(SourcemapCollection) bundle,
    required final R Function(SourcemapSingle) single,
  }) =>
      multi(this);
}

class SourcemapCollectionImpl implements SourcemapCollection {
  @override
  final Map<String, SourcemapSingle> mappings;

  SourcemapCollectionImpl() : mappings = {};

  @override
  void addMapping(
    final SourcemapSingle mapping,
  ) {
    mappings[mapping.target_url] = mapping;
  }

  @override
  String toString() {
    final buff = StringBuffer();
    for (final map in mappings.values) {
      buff.write(map.toString());
    }
    return buff.toString();
  }

  @override
  bool containsMapping(
    final String url,
  ) =>
      mappings.containsKey(url);

  @override
  R match<R>({
    required final R Function(SourcemapMultisection) multi,
    required final R Function(SourcemapCollection) bundle,
    required final R Function(SourcemapSingle) single,
  }) =>
      bundle(this);
}

class SourcemapSingleImpl implements SourcemapSingle {
  @override
  final List<String> urls;
  @override
  final List<String> names;
  @override
  final List<SourcemapFile?> files;
  @override
  final List<SourcemapTargetLineEntry> lines;
  @override
  final String target_url;
  @override
  final String? source_root;
  @override
  final Uri? map_url;
  @override
  final Map<String, Object> extensions;

  const SourcemapSingleImpl({
    required final this.target_url,
    required final this.files,
    required final this.urls,
    required final this.names,
    required final this.lines,
    required final this.map_url,
    required final this.extensions,
    required final this.source_root,
  });

  @override
  SourcemapSingle copy_with_new_source_root(
    final String new_source_root,
  ) {
    return SourcemapSingleImpl(
      target_url: target_url,
      files: files,
      urls: urls,
      names: names,
      lines: lines,
      map_url: map_url,
      extensions: extensions,
      source_root: new_source_root,
    );
  }

  @override
  R match<R>({
    required final R Function(SourcemapMultisection) multi,
    required final R Function(SourcemapCollection) bundle,
    required final R Function(SourcemapSingle) single,
  }) =>
      single(this);
}

class SourcemapSpanImpl implements SourcemapSpan {
  @override
  final SourcemapLocationSmart end;
  @override
  final SourcemapLocationSmart start;
  @override
  final String text;
  @override
  final bool is_identifier;
  @override
  final Uri? sourceUrl;

  const SourcemapSpanImpl({
    required final this.start,
    required final this.end,
    required final this.text,
    required final this.is_identifier,
    required final this.sourceUrl,
  });
}

class SourcemapTargetLineEntryImpl implements SourcemapTargetLineEntry {
  @override
  final int line;
  @override
  final List<SourcemapTargetEntry> entries;

  const SourcemapTargetLineEntryImpl({
    required final this.line,
    required final this.entries,
  });
}

class SourcemapTargetEntryImpl implements SourcemapTargetEntry {
  @override
  final int column;
  @override
  final int? source_url_id;
  @override
  final int? source_line;
  @override
  final int? source_column;
  @override
  final int? source_name_id;

  const SourcemapTargetEntryImpl({
    required final this.column,
    final this.source_url_id,
    final this.source_line,
    final this.source_column,
    final this.source_name_id,
  });
}

class SourcemapLocationImpl implements SourcemapLocationSmart {
  @override
  final int offset;
  @override
  final int line;
  @override
  final int column;
  @override
  final Uri? sourceUrl;
  @override
  final SourcemapFile? file;

  const SourcemapLocationImpl({
    required final this.offset,
    required final this.line,
    required final this.column,
    required final this.sourceUrl,
    required final this.file,
  });
}

class SourcemapFileImpl implements SourcemapFile {
  @override
  final String content;
  @override
  final Uri? url;

  const SourcemapFileImpl({
    required final this.content,
    required final this.url,
  });
}
