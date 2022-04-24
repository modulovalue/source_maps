import 'dart:convert';
import 'dart:io';

import 'package:source_maps2/json_to_sourcemap.dart';
import 'package:source_maps2/sourcemap_comment.dart';

import 'util.dart';

void main() {
  // Read out.js.
  final generated_js = self_dir_file(
    type: _Type,
    file_name: "data/out.js",
  );
  final generated_js_path = Uri.parse(generated_js.path);
  // Extract sourcemap comment.
  extract_sourcemap_comment(
    lines: generated_js.readAsLinesSync(),
  ).match(
    inline: (final a) => throw Exception(a),
    invalid: (final a) => throw Exception(a),
    path: (final a) {
      final sourcemap_uri = generated_js_path.resolveUri(a.path);
      final sourcemap_contents = File.fromUri(sourcemap_uri).readAsStringSync();
      final dynamic sourcemap_json = jsonDecode(sourcemap_contents);
      sourcemap_from_json(
        json: sourcemap_json,
        source_map_file_url: sourcemap_uri,
      ).match(
        multi: (final a) => throw Exception(a),
        bundle: (final a) => throw Exception(a),
        single: (final a) {
          print(a.urls.asMap().entries.map((final a) => "${a.key}: ${a.value}").join("\n"));
          // print(a.names.asMap().entries.join("\n"));
          // print("target url: ${a.target_url}");
          // print("source root: ${a.source_root}");
          print("map url: ${a.map_url}");
          // print("extensions: ${const JsonEncoder.withIndent(" ").convert(a.extensions)}");
          for (final line in a.lines) {
            print("Line: ${line.line + 1}");
            entryfor:
            for (final entry in line.entries) {
              final column = entry.column;
              final source_url_id = entry.source_url_id;
              final source_line = entry.source_line;
              final source_name_id = entry.source_name_id;
              final source_column = entry.source_column;
              if (source_url_id != null) {
                if (a.urls[source_url_id].startsWith("org-dartlang-sdk://")) {
                  continue entryfor;
                }
              } else {
                continue entryfor;
              }
              void output(
                final String str,
              ) {
                print(" '- " + str);
              }
              output("column: ${column}");
              output("source_url: ${a.urls[source_url_id]} (${source_url_id})");
              final file = a.files[source_url_id];
              if (file != null) {
                output(" • has file");
              }
              if (source_line != null) {
                output("source_line: ${source_line}");
              }
              if (source_name_id != null) {
                output("source_name_id: ${a.names[source_name_id]} (${source_name_id})");
              }
              output("source_column: ${source_column}");
              print("");
            }
          }
        },
      );
    },
  );
}

abstract class _Type {}
