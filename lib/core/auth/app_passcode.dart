import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Hashing and checking for the app-lock password (T4).
///
/// The password itself never touches disk and is never logged: what is stored
/// in SharedPreferences is a per-password random 16-byte salt and the SHA-256
/// of salt-then-UTF-8-password, encoded as `<salt-hex>:<hash-hex>`. A fresh
/// salt on every [hash] call means two students choosing the same word store
/// different bytes.
///
/// [verify] compares the computed hash against the stored one byte-wise,
/// accumulating a difference across the whole string rather than returning at
/// the first mismatch. Against a 256-bit digest this is belt-and-braces, but
/// it costs nothing and removes the question.
abstract final class AppPasscode {
  /// The floor for a *new* password, enforced by every caller that sets one.
  ///
  /// Deliberately small -- this is a privacy lock on a phone that already has
  /// its own screen lock behind it, not a bank credential; a floor a student
  /// cannot remember past is a lock they turn off.
  static const int minLength = 4;

  static final Random _random = Random.secure();

  /// Hashes [password] under a fresh random salt.
  static String hash(String password) {
    final salt =
        List<int>.generate(16, (_) => _random.nextInt(256));
    return _encode(salt, _digest(salt, password));
  }

  /// Whether [password] answers to a value [hash] produced.
  ///
  /// Anything malformed in [stored] fails closed: a truncated or corrupt
  /// preference must read as "wrong", never as an exception or -- worse --
  /// as a match.
  static bool verify(String password, String stored) {
    final parts = stored.split(':');
    if (parts.length != 2) return false;
    final salt = _parseHex(parts[0]);
    if (salt == null || salt.isEmpty) return false;
    return _constantTimeEquals(_hex(_digest(salt, password)), parts[1]);
  }

  /// Whether every character is an ASCII digit.
  ///
  /// Recorded alongside the hash so the gate can raise the numeric keyboard
  /// for a PIN-shaped password. It says nothing about *what* the digits are;
  /// only that they are digits.
  static bool looksNumeric(String password) =>
      RegExp(r'^[0-9]+$').hasMatch(password);

  static List<int> _digest(List<int> salt, String password) => sha256
      .convert(<int>[...salt, ...utf8.encode(password)])
      .bytes;

  static String _encode(List<int> salt, List<int> digest) =>
      '${_hex(salt)}:${_hex(digest)}';

  /// Walks both strings once, XOR-accumulating every position. Length is not
  /// secret here (a hex digest is always 64 characters), so the early exit on
  /// length gives nothing away.
  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  static String _hex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  static List<int>? _parseHex(String hex) {
    if (hex.isEmpty || hex.length.isOdd) return null;
    try {
      return List<int>.generate(
        hex.length ~/ 2,
        (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16),
      );
    } on FormatException {
      return null;
    }
  }
}
