import 'dart:convert';

import 'constants.dart';

String build_sourcemap_comment_path({
  required final String path,
}) {
  assert(
    LineSplitter.split(path).length == 1,
    "The given path can't contain any newlines.",
  );
  return sourcemap_comment_indicator + path;
}

String build_sourcemap_comment_json_utf8_base64_inline({
  required final /*Uint8List*/ List<int> bytes,
}) {
  return sourcemap_comment_indicator + "data:application/json;charset=utf-8;base64," + base64.encode(bytes);
}
