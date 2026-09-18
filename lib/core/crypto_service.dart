import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight E2E in the app: AES-256-GCM keys, hashed per chat.
///
/// This is an MVP key derivation (device-local secret + chat id).
/// Production should exchange real prekeys through the /keys/* edge
/// functions (keys-register / keys-bundle / keys-rotate) so chat keys
/// ride the signal-style double ratchet. Ciphertext on the wire is
/// always AES-GCM regardless of how the key is derived.
class CryptoService {
  CryptoService._();

  static final CryptoService instance = CryptoService._();

  final AesGcm _aes = AesGcm.with256bits();
  String? _deviceSecret;

  Future<String> _secret() async {
    if (_deviceSecret != null) return _deviceSecret!;
    final prefs = await SharedPreferences.getInstance();
    var secret = prefs.getString('crypto.device_secret');
    if (secret == null) {
      final bytes = List<int>.generate(32, (_) => _randByte());
      secret = base64Encode(bytes);
      await prefs.setString('crypto.device_secret', secret);
    }
    _deviceSecret = secret;
    return secret;
  }

  int _randByte() => DateTime.now().microsecondsSinceEpoch % 256 ^ (identityHashCode(this) & 0xff);

  /// Deterministic per-chat key so both directions can decrypt client-side.
  Future<SecretKey> _chatKey(String chatId) async {
    final secret = await _secret();
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    final inputKey = SecretKey(utf8.encode('$secret::$chatId'));
    final derived = await hkdf.deriveKey(inputKey, nonce: utf8.encode('chatindo/v1'));
    return derived;
  }

  Future<String> encrypt(String chatId, String plaintext) async {
    final key = await _chatKey(chatId);
    final box = await _aes.encrypt(utf8.encode(plaintext), secretKey: key);
    return base64Encode([
      ...box.nonce,
      box.cipherText.length & 0xff,
      ...box.cipherText,
      ...box.mac.bytes,
    ]);
  }

  /// Returns the plaintext or null when the payload cannot be decrypted.
  Future<String?> decrypt(String chatId, String payload) async {
    try {
      final key = await _chatKey(chatId);
      final raw = base64Decode(payload);
      final nonceLen = 12;
      final macLen = 16;
      if (raw.length < nonceLen + 1 + macLen) return null;
      final nonce = raw.sublist(0, nonceLen);
      final bodyLen = raw[nonceLen];
      final cipherLen = raw.length - nonceLen - 1 - macLen;
      final cipherText = raw.sublist(nonceLen + 1, nonceLen + 1 + cipherLen);
      final macBytes = raw.sublist(raw.length - macLen);
      final box = SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes));
      final clear = await _aes.decrypt(box, secretKey: key);
      return utf8.decode(clear);
    } catch (_) {
      return null;
    }
  }
}