import 'sourcemap.dart';
import 'vlq.dart';

/// Encodes the Mapping mappings as a json map.
List<Map<String, Object>> sourcemap_bundle_to_json({
  required final SourcemapCollection sourcemap,
  required final bool include_source_contents,
}) {
  return [
    for (final v in sourcemap.mappings.values)
      sourcemap_single_to_json(
        sourcemap: v,
        include_source_contents: include_source_contents,
      ),
  ];
}

/// Encodes the Mapping mappings as a json map.
///
/// If [include_source_contents] is `true`, this includes the source file
/// contents from files in the map if possible.
Map<String, Object> sourcemap_single_to_json({
  required final SourcemapSingle sourcemap,
  required final bool include_source_contents,
}) {
  return {
    'version': 3,
    'sourceRoot': sourcemap.source_root ?? '',
    'sources': sourcemap.urls,
    'names': sourcemap.names,
    'mappings': () {
      final buff = StringBuffer();
      int line = 0;
      int column = 0;
      int srcLine = 0;
      int srcColumn = 0;
      int srcUrlId = 0;
      int srcNameId = 0;
      bool first = true;
      for (final entry in sourcemap.lines) {
        final nextLine = entry.line;
        if (nextLine > line) {
          for (int i = line; i < nextLine; ++i) {
            buff.write(';');
          }
          line = nextLine;
          column = 0;
          first = true;
        }
        for (final segment in entry.entries) {
          if (!first) {
            buff.write(',');
          }
          first = false;
          column = Vlq.add_vlq_to_buffer(
            buff: buff,
            old_value: column,
            new_value: segment.column,
          );
          // Encoding can be just the column offset if there is no source
          // information.
          final newUrlId = segment.source_url_id;
          if (newUrlId != null) {
            srcUrlId = Vlq.add_vlq_to_buffer(
              buff: buff,
              old_value: srcUrlId,
              new_value: newUrlId,
            );
            srcLine = Vlq.add_vlq_to_buffer(
              buff: buff,
              old_value: srcLine,
              new_value: segment.source_line!,
            );
            srcColumn = Vlq.add_vlq_to_buffer(
              buff: buff,
              old_value: srcColumn,
              new_value: segment.source_column!,
            );
            if (segment.source_name_id != null) {
              srcNameId = Vlq.add_vlq_to_buffer(
                buff: buff,
                old_value: srcNameId,
                new_value: segment.source_name_id!,
              );
            }
          }
        }
      }
      return buff.toString();
    }(),
    'file': sourcemap.target_url,
    if (include_source_contents)
      'sourcesContent': [
        for (final file in sourcemap.files) file,
      ],
    ...sourcemap.extensions,
  };
}
