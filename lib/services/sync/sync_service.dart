import '../../models/call_entry.dart';
import '../local_call_store.dart';
import '../settings_store.dart';
import 'crypto_util.dart';
import 'custom_rest_sync_backend.dart';
import 'pocketbase_sync_backend.dart';
import 'sync_backend.dart';
import 'sync_row.dart';
import 'supabase_sync_backend.dart';

class SyncResult {
  final int pushed;
  final int pulled;
  final String? error;
  const SyncResult({this.pushed = 0, this.pulled = 0, this.error});
  bool get ok => error == null;
}

class SyncService {
  final SettingsStore store;
  final LocalCallStore localStore;

  SyncService({required this.store, required this.localStore});

  /// Χτίζει το σωστό backend με βάση τις τρέχουσες ρυθμίσεις.
  /// Πετάει [SyncBackendException] αν λείπουν στοιχεία σύνδεσης.
  SyncBackend buildBackend() {
    final url = store.syncServerUrl.trim();
    final key = store.syncApiKey.trim();
    if (url.isEmpty || key.isEmpty) {
      throw const SyncBackendException(
        'Λείπουν το URL ή το API Key/Token στις ρυθμίσεις συγχρονισμού.',
      );
    }
    switch (store.syncBackend) {
      case 'pocketbase':
        return PocketBaseSyncBackend(baseUrl: url, authToken: key);
      case 'custom':
        return CustomRestSyncBackend(baseUrl: url, authValue: key);
      case 'supabase':
      default:
        return SupabaseSyncBackend(projectUrl: url, anonKey: key);
    }
  }

  Future<void> testConnection() async {
    await buildBackend().testConnection();
  }

  /// Πλήρης κύκλος: push ό,τι είναι τοπικό & μη-συγχρονισμένο, μετά pull
  /// ό,τι νεότερο υπάρχει στο backend. Ασφαλές να καλείται συχνά - δεν
  /// ξανά-ανεβάζει/κατεβάζει ό,τι έχει ήδη γίνει.
  Future<SyncResult> syncNow() async {
    if (!store.syncEnabled) {
      return const SyncResult(error: 'Ο συγχρονισμός δεν είναι ενεργός.');
    }
    final password = store.syncEncryptionPassword;
    if (password.isEmpty) {
      return const SyncResult(
        error: 'Δεν έχει οριστεί κωδικός τοπικής κρυπτογράφησης.',
      );
    }

    late final SyncBackend backend;
    try {
      backend = buildBackend();
    } on SyncBackendException catch (e) {
      return SyncResult(error: e.message);
    }

    var pushed = 0;
    var pulled = 0;

    try {
      // --- PUSH ---
      final unsynced = await localStore.getUnsynced();
      if (unsynced.isNotEmpty) {
        final rows = <SyncRow>[];
        final now = DateTime.now().toUtc();
        for (final entry in unsynced) {
          final blob = await SyncCrypto.encryptJson(entry.toJson(), password);
          rows.add(SyncRow(
            entryId: entry.id,
            deviceOrigin: entry.deviceOrigin,
            payload: blob,
            updatedAt: now,
          ));
        }
        // Batches των 50 ώστε ένα μεγάλο πρώτο sync να μην κάνει ένα τεράστιο request.
        for (var i = 0; i < rows.length; i += 50) {
          final chunk = rows.sublist(i, i + 50 > rows.length ? rows.length : i + 50);
          await backend.pushRows(chunk);
        }
        await localStore.markSynced(unsynced.map((e) => e.id));
        pushed = unsynced.length;
      }

      // --- PULL ---
      final since = store.syncLastPulledAt;
      final remoteRows = await backend.pullRows(since);
      DateTime? maxUpdatedAt = since;
      for (final row in remoteRows) {
        try {
          final json = await SyncCrypto.decryptJson(row.payload, password);
          final entry = CallEntry.fromJson(json).copyWith(synced: true);
          await localStore.insertFromRemote(entry);
          pulled++;
        } on SyncDecryptionException {
          // Λάθος κωδικός ή αλλοιωμένη εγγραφή - την αγνοούμε, δεν
          // σταματάμε όλο το sync εξαιτίας μίας κακής εγγραφής.
          continue;
        }
        if (maxUpdatedAt == null || row.updatedAt.isAfter(maxUpdatedAt)) {
          maxUpdatedAt = row.updatedAt;
        }
      }
      if (maxUpdatedAt != null) {
        await store.setSyncLastPulledAt(maxUpdatedAt);
      }

      return SyncResult(pushed: pushed, pulled: pulled);
    } on SyncBackendException catch (e) {
      return SyncResult(pushed: pushed, pulled: pulled, error: e.message);
    } catch (e) {
      return SyncResult(pushed: pushed, pulled: pulled, error: e.toString());
    }
  }
}
