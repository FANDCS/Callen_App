import 'dart:convert';
import 'package:http/http.dart' as http;

import 'sync_backend.dart';
import 'sync_row.dart';

/// "Universal" backend: μιλάει με ΟΠΟΙΟΝΔΗΠΟΤΕ δικό σου server, αρκεί να
/// υλοποιεί το απλό contract που περιγράφεται στο
/// sync-backend/custom_rest_api.md (3 endpoints: ping/push/pull).
///
/// Δεν υποθέτουμε ΤΙΠΟΤΑ για το πώς κάνεις auth στον server σου: ό,τι
/// γράψεις στο πεδίο "API Key / Token" πάει ΑΥΤΟΛΕΞΕΙ στο header
/// `Authorization`. Αν το γράψεις ήδη με το σωστό scheme (π.χ.
/// `Bearer xyz`, `Basic base64(user:pass)`, `Token abc123`), μένει όπως
/// είναι. Αν γράψεις απλά μια τιμή χωρίς scheme, την στέλνουμε ως
/// `Bearer <τιμή>` (η πιο συνηθισμένη σύμβαση) — έτσι καλύπτονται τα
/// περισσότερα custom backends χωρίς να χρειάζεται ξεχωριστό πεδίο για
/// "τύπο auth".
class CustomRestSyncBackend implements SyncBackend {
  final String baseUrl;
  final String authValue;

  CustomRestSyncBackend({required String baseUrl, required this.authValue})
      : baseUrl = baseUrl.endsWith('/')
            ? baseUrl.substring(0, baseUrl.length - 1)
            : baseUrl;

  String get _authorizationHeader {
    final looksLikeScheme = RegExp(r'^[A-Za-z][A-Za-z0-9._-]*\s+\S+')
        .hasMatch(authValue.trim());
    return looksLikeScheme ? authValue.trim() : 'Bearer ${authValue.trim()}';
  }

  Map<String, String> get _headers => {
        'Authorization': _authorizationHeader,
        'Content-Type': 'application/json',
      };

  @override
  Future<void> testConnection() async {
    final uri = Uri.parse('$baseUrl/call_entries/ping');
    final res = await http.get(uri, headers: _headers).timeout(
          const Duration(seconds: 10),
        );
    if (res.statusCode >= 400) {
      throw SyncBackendException(
        'Custom server error ${res.statusCode}: ${_shortBody(res.body)}',
      );
    }
  }

  @override
  Future<void> pushRows(List<SyncRow> rows) async {
    if (rows.isEmpty) return;
    final uri = Uri.parse('$baseUrl/call_entries/push');
    final body = jsonEncode({
      'rows': rows
          .map((r) => {
                'entry_id': r.entryId,
                'device_origin': r.deviceOrigin,
                'payload': r.payload,
                'updated_at': r.updatedAt.toUtc().toIso8601String(),
              })
          .toList(),
    });

    final res = await http
        .post(uri, headers: _headers, body: body)
        .timeout(const Duration(seconds: 20));

    if (res.statusCode >= 400) {
      throw SyncBackendException(
        'Custom server push failed (${res.statusCode}): ${_shortBody(res.body)}',
      );
    }
  }

  @override
  Future<List<SyncRow>> pullRows(DateTime? since) async {
    final query = <String, String>{
      if (since != null) 'since': since.toUtc().toIso8601String(),
    };
    final uri = Uri.parse('$baseUrl/call_entries/pull').replace(
      queryParameters: query.isEmpty ? null : query,
    );

    final res = await http.get(uri, headers: _headers).timeout(
          const Duration(seconds: 20),
        );

    if (res.statusCode >= 400) {
      throw SyncBackendException(
        'Custom server pull failed (${res.statusCode}): ${_shortBody(res.body)}',
      );
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final items = data['rows'] as List<dynamic>? ?? [];
    return items.map((raw) {
      final m = raw as Map<String, dynamic>;
      return SyncRow(
        entryId: m['entry_id'] as String,
        deviceOrigin: m['device_origin'] as String? ?? '',
        payload: m['payload'] as String,
        updatedAt: DateTime.parse(m['updated_at'] as String),
      );
    }).toList();
  }

  String _shortBody(String body) =>
      body.length > 200 ? '${body.substring(0, 200)}…' : body;
}
