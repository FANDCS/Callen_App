import 'dart:convert';
import 'package:http/http.dart' as http;

import 'sync_backend.dart';
import 'sync_row.dart';

/// Backend μέσω του αυτόματου REST API του Supabase (PostgREST) πάνω στον
/// πίνακα `call_entries` (δες το schema.sql που δίνεται μαζί με το app).
///
/// Δεν χρησιμοποιούμε το πακέτο `supabase_flutter` επίτηδες: το REST API
/// του Supabase είναι ένα απλό PostgREST endpoint, οπότε λίγα HTTP calls
/// αρκούν και δουλεύουν πανομοιότυπα σε Android/Linux/Windows χωρίς καμία
/// πρόσθετη native εξάρτηση.
class SupabaseSyncBackend implements SyncBackend {
  final String projectUrl; // π.χ. https://xxxx.supabase.co
  final String anonKey;
  static const _table = 'call_entries';

  SupabaseSyncBackend({required String projectUrl, required this.anonKey})
      : projectUrl = projectUrl.endsWith('/')
            ? projectUrl.substring(0, projectUrl.length - 1)
            : projectUrl;

  Map<String, String> get _headers => {
        'apikey': anonKey,
        'Authorization': 'Bearer $anonKey',
        'Content-Type': 'application/json',
      };

  @override
  Future<void> testConnection() async {
    final uri = Uri.parse('$projectUrl/rest/v1/$_table?select=entry_id&limit=1');
    final res = await http.get(uri, headers: _headers).timeout(
          const Duration(seconds: 10),
        );
    if (res.statusCode >= 400) {
      throw SyncBackendException(
        'Supabase error ${res.statusCode}: ${_shortBody(res.body)}',
      );
    }
  }

  @override
  Future<void> pushRows(List<SyncRow> rows) async {
    if (rows.isEmpty) return;
    final uri = Uri.parse('$projectUrl/rest/v1/$_table');
    final body = rows
        .map((r) => {
              'entry_id': r.entryId,
              'device_origin': r.deviceOrigin,
              'payload': r.payload,
              'updated_at': r.updatedAt.toUtc().toIso8601String(),
            })
        .toList();

    final res = await http
        .post(
          uri,
          headers: {
            ..._headers,
            // upsert: αν υπάρχει ήδη entry_id, το κάνει update αντί να
            // σκάσει σε conflict· δεν χρειαζόμαστε το response σώμα πίσω.
            'Prefer': 'resolution=merge-duplicates,return=minimal',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 20));

    if (res.statusCode >= 400) {
      throw SyncBackendException(
        'Supabase push failed (${res.statusCode}): ${_shortBody(res.body)}',
      );
    }
  }

  @override
  Future<List<SyncRow>> pullRows(DateTime? since) async {
    final params = <String, String>{
      'select': 'entry_id,device_origin,payload,updated_at',
      'order': 'updated_at.asc',
    };
    if (since != null) {
      params['updated_at'] = 'gt.${since.toUtc().toIso8601String()}';
    }
    final uri = Uri.parse('$projectUrl/rest/v1/$_table').replace(
      queryParameters: params,
    );

    final res = await http.get(uri, headers: _headers).timeout(
          const Duration(seconds: 20),
        );

    if (res.statusCode >= 400) {
      throw SyncBackendException(
        'Supabase pull failed (${res.statusCode}): ${_shortBody(res.body)}',
      );
    }

    final list = jsonDecode(res.body) as List<dynamic>;
    return list.map((raw) {
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
