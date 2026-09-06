import 'dart:convert';
import 'package:http/http.dart' as http;

import 'sync_backend.dart';
import 'sync_row.dart';

/// Backend μέσω του REST API του PocketBase πάνω στη συλλογή `call_entries`
/// (δες pocketbase_schema.md). Δεν χρησιμοποιούμε το επίσημο πακέτο
/// `pocketbase` dart SDK, ίδια λογική με το Supabase backend: μερικά HTTP
/// calls αρκούν και δεν προσθέτουν εξαρτήσεις.
///
/// ΣΗΜΑΝΤΙΚΟ: το PocketBase δεν υποστηρίζει "upsert" σε ένα call, ούτε
/// custom primary keys με το μήκος ενός uuid v4. Γι' αυτό κρατάμε το δικό
/// μας [SyncRow.entryId] σε ΞΕΧΩΡΙΣΤΟ πεδίο (`entry_id`, με unique index)
/// και αφήνουμε το PocketBase να διαχειρίζεται το δικό του `id`.
class PocketBaseSyncBackend implements SyncBackend {
  final String baseUrl; // π.χ. https://my-pb.example.com
  final String authToken; // token χρήστη/admin (Settings -> "PocketBase Admin Token")
  static const _collection = 'call_entries';

  PocketBaseSyncBackend({required String baseUrl, required this.authToken})
      : baseUrl = baseUrl.endsWith('/')
            ? baseUrl.substring(0, baseUrl.length - 1)
            : baseUrl;

  Map<String, String> get _headers => {
        'Authorization': authToken,
        'Content-Type': 'application/json',
      };

  Uri _recordsUri([Map<String, String>? query]) => Uri.parse(
        '$baseUrl/api/collections/$_collection/records',
      ).replace(queryParameters: query);

  @override
  Future<void> testConnection() async {
    final uri = _recordsUri({'perPage': '1'});
    final res = await http.get(uri, headers: _headers).timeout(
          const Duration(seconds: 10),
        );
    if (res.statusCode >= 400) {
      throw SyncBackendException(
        'PocketBase error ${res.statusCode}: ${_shortBody(res.body)}',
      );
    }
  }

  @override
  Future<void> pushRows(List<SyncRow> rows) async {
    for (final row in rows) {
      await _upsertOne(row);
    }
  }

  Future<void> _upsertOne(SyncRow row) async {
    // 1. Ψάχνουμε αν υπάρχει ήδη μια εγγραφή με αυτό το entry_id.
    final filterUri = _recordsUri({
      'filter': '(entry_id="${row.entryId}")',
      'perPage': '1',
    });
    final existingRes = await http
        .get(filterUri, headers: _headers)
        .timeout(const Duration(seconds: 15));
    if (existingRes.statusCode >= 400) {
      throw SyncBackendException(
        'PocketBase lookup failed (${existingRes.statusCode}): '
        '${_shortBody(existingRes.body)}',
      );
    }
    final existing = jsonDecode(existingRes.body) as Map<String, dynamic>;
    final items = existing['items'] as List<dynamic>? ?? [];

    final body = jsonEncode({
      'entry_id': row.entryId,
      'device_origin': row.deviceOrigin,
      'payload': row.payload,
      'client_updated_at': row.updatedAt.toUtc().toIso8601String(),
    });

    if (items.isEmpty) {
      // 2a. Δεν υπάρχει -> create.
      final res = await http
          .post(_recordsUri(), headers: _headers, body: body)
          .timeout(const Duration(seconds: 15));
      if (res.statusCode >= 400) {
        throw SyncBackendException(
          'PocketBase create failed (${res.statusCode}): '
          '${_shortBody(res.body)}',
        );
      }
    } else {
      // 2b. Υπάρχει -> update πάνω στο δικό του PocketBase id.
      final pbId = (items.first as Map<String, dynamic>)['id'] as String;
      final res = await http
          .patch(
            Uri.parse(
              '$baseUrl/api/collections/$_collection/records/$pbId',
            ),
            headers: _headers,
            body: body,
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode >= 400) {
        throw SyncBackendException(
          'PocketBase update failed (${res.statusCode}): '
          '${_shortBody(res.body)}',
        );
      }
    }
  }

  @override
  Future<List<SyncRow>> pullRows(DateTime? since) async {
    final query = <String, String>{
      'sort': '+client_updated_at',
      'perPage': '200',
    };
    if (since != null) {
      query['filter'] = '(client_updated_at>"${since.toUtc().toIso8601String()}")';
    }

    final rows = <SyncRow>[];
    var page = 1;
    while (true) {
      final uri = _recordsUri({...query, 'page': '$page'});
      final res = await http.get(uri, headers: _headers).timeout(
            const Duration(seconds: 20),
          );
      if (res.statusCode >= 400) {
        throw SyncBackendException(
          'PocketBase pull failed (${res.statusCode}): ${_shortBody(res.body)}',
        );
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final items = data['items'] as List<dynamic>? ?? [];
      for (final raw in items) {
        final m = raw as Map<String, dynamic>;
        rows.add(SyncRow(
          entryId: m['entry_id'] as String,
          deviceOrigin: m['device_origin'] as String? ?? '',
          payload: m['payload'] as String,
          updatedAt: DateTime.parse(m['client_updated_at'] as String),
        ));
      }
      final totalPages = data['totalPages'] as int? ?? 1;
      if (page >= totalPages || items.isEmpty) break;
      page++;
    }
    return rows;
  }

  String _shortBody(String body) =>
      body.length > 200 ? '${body.substring(0, 200)}…' : body;
}
