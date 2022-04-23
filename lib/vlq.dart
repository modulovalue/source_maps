import 'dart:math';

/// Utilities to encode and decode VLQ values used in source maps.
///
/// Sourcemaps are encoded with variable length numbers as base64 encoded
/// strings with the least significant digit coming first. Each base64 digit
/// encodes a 5-bit value (0-31) and a continuation bit. Signed values can be
/// represented by using the least significant bit of the value as the sign bit.
///
/// For more details see the source map [version 3 documentation](https://docs.google.com/document/d/1U1RGAehQwRypUTovF1KRlpiOFze0b-_2gc6fAH0KY0k/edit?usp=sharing).
abstract class Vlq {
  static int add_vlq_to_buffer({
    required final StringBuffer buff,
    required final int old_value,
    required final int new_value,
  }) {
    buff.writeAll(
      Vlq.encode_vlq(
        new_value - old_value,
      ),
    );
    return new_value;
  }

  /// Creates the VLQ encoding of [value] as a sequence of characters
  static Iterable<String> encode_vlq(
    int value,
  ) {
    if (value < _minInt32 || value > _maxInt32) {
      throw ArgumentError('expected 32 bit int, got: $value');
    } else {
      final res = <String>[];
      var signBit = 0;
      if (value < 0) {
        signBit = 1;
        // ignore: parameter_assignments
        value = -value;
      }
      // ignore: parameter_assignments
      value = (value << 1) | signBit;
      do {
        var digit = value & _vlqBaseMask;
        // ignore: parameter_assignments
        value >>= _vlqBaseShift;
        if (value > 0) {
          digit |= _vlqContinuationBit;
        }
        res.add(_base64Digits[digit]);
      } while (value > 0);
      return res;
    }
  }

  /// Decodes a value written as a sequence of VLQ characters. The first input
  /// character will be `chars.current` after calling `chars.moveNext` once. The
  /// iterator is advanced until a stop character is found (a character without
  /// the [_vlqContinuationBit]).
  static int decode_vlq(
    final Iterator<String> chars,
  ) {
    var result = 0;
    var stop = false;
    var shift = 0;
    while (!stop) {
      if (!chars.moveNext()) throw StateError('incomplete VLQ value');
      final char = chars.current;
      var digit = _digits[char];
      if (digit == null) {
        throw FormatException('invalid character in VLQ encoding: $char');
      } else {
        stop = (digit & _vlqContinuationBit) == 0;
        digit &= _vlqBaseMask;
        result += digit << shift;
        shift += _vlqBaseShift;
      }
    }
    // Result uses the least significant bit as a sign bit. We convert it into a
    // two-complement value. For example,
    //   2 (10 binary) becomes 1
    //   3 (11 binary) becomes -1
    //   4 (100 binary) becomes 2
    //   5 (101 binary) becomes -2
    //   6 (110 binary) becomes 3
    //   7 (111 binary) becomes -3
    final negate = (result & 1) == 1;
    result = result >> 1;
    result = negate ? -result : result;
    // TODO(sigmund): can we detect this earlier?
    if (result < _minInt32 || result > _maxInt32) {
      throw FormatException('expected an encoded 32 bit int, but we got: $result');
    } else {
      return result;
    }
  }

  static const int _vlqBaseShift = 5;
  static const int _vlqBaseMask = (1 << 5) - 1;
  static const int _vlqContinuationBit = 1 << 5;
  static const String _base64Digits = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
  static final Map<String, int> _digits = () {
    final map = <String, int>{};
    for (var i = 0; i < 64; i++) {
      map[_base64Digits[i]] = i;
    }
    return map;
  }();
  static final int _maxInt32 = (pow(2, 31) as int) - 1;
  static final int _minInt32 = -(pow(2, 31) as int);
}
