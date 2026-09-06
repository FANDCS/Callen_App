import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Κρυπτογράφηση/αποκρυπτογράφηση των δεδομένων ΠΡΙΝ φύγουν προς το
/// Supabase/PocketBase. Ο server βλέπει μόνο ένα άσχετο blob από bytes -
/// ποτέ τον αριθμό τηλεφώνου, το όνομα επαφής, ή οτιδήποτε άλλο σε
/// καθαρό κείμενο.
///
/// Format του αποθηκευμένου blob (όλα μαζί, base64):
///   [ 16 bytes salt ][ 12 bytes nonce ][ ciphertext ][ 16 bytes MAC tag ]
///
/// Το salt είναι τυχαίο ΑΝΑ ΕΓΓΡΑΦΗ ώστε δύο ίδιες εγγραφές να μην παράγουν
/// ποτέ το ίδιο ciphertext (semantic security), ακόμα κι αν χρησιμοποιείται
/// ο ίδιος κωδικός σε όλες τις συσκευές.
class SyncCrypto {
  static const _saltLength = 16;
  static final _algorithm = AesGcm.with256bits();
  static final _random = Random.secure();

  /// Κρυπτογραφεί ένα JSON-serializable Map και επιστρέφει ένα base64 blob
  /// έτοιμο να ανέβει στο backend.
  static Future<String> encryptJson(
    Map<String, dynamic> json,
    String password,
  ) async {
    final plaintext = utf8.encode(jsonEncode(json));
    final salt = _randomBytes(_saltLength);
    final secretKey = await _deriveKey(password, salt);
    final nonce = _algorithm.newNonce();

    final secretBox = await _algorithm.encrypt(
      plaintext,
      secretKey: secretKey,
      nonce: nonce,
    );

    final combined = BytesBuilder()
      ..add(salt)
      ..add(secretBox.nonce)
      ..add(secretBox.cipherText)
      ..add(secretBox.mac.bytes);

    return base64Encode(combined.toBytes());
  }

  /// Αντίστροφο του [encryptJson]. Πετάει [SyncDecryptionException] αν ο
  /// κωδικός είναι λάθος ή το blob έχει αλλοιωθεί (αποτυχία MAC = δεν το
  /// εμπιστευόμαστε ποτέ σιωπηλά).
  static Future<Map<String, dynamic>> decryptJson(
    String blobBase64,
    String password,
  ) async {
    final raw = base64Decode(blobBase64);
    if (raw.length < _saltLength + 12 + 16) {
      throw const SyncDecryptionException('Corrupted sync payload (too short)');
    }

    final salt = raw.sublist(0, _saltLength);
    final nonce = raw.sublist(_saltLength, _saltLength + 12);
    final macBytes = raw.sublist(raw.length - 16);
    final cipherText = raw.sublist(_saltLength + 12, raw.length - 16);

    final secretKey = await _deriveKey(password, salt);
    final secretBox = SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes));

    try {
      final plaintext = await _algorithm.decrypt(
        secretBox,
        secretKey: secretKey,
      );
      final map = jsonDecode(utf8.decode(plaintext));
      return map as Map<String, dynamic>;
    } on SecretBoxAuthenticationError {
      throw const SyncDecryptionException(
        'Wrong encryption password, or the data was tampered with',
      );
    }
  }

  static Future<SecretKey> _deriveKey(String password, List<int> salt) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: 100000,
      bits: 256,
    );
    return pbkdf2.deriveKeyFromPassword(password: password, nonce: salt);
  }

  static Uint8List _randomBytes(int length) {
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = _random.nextInt(256);
    }
    return bytes;
  }
}

class SyncDecryptionException implements Exception {
  final String message;
  const SyncDecryptionException(this.message);
  @override
  String toString() => 'SyncDecryptionException: $message';
}
