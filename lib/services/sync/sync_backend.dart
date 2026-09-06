import 'sync_row.dart';

/// Κοινό interface - το [SyncService] δεν ξέρει (ούτε τον νοιάζει) αν
/// μιλάει με Supabase ή PocketBase.
abstract class SyncBackend {
  /// Ανεβάζει (insert-or-update) τις δοσμένες γραμμές. Πρέπει να είναι
  /// idempotent με βάση το [SyncRow.entryId].
  Future<void> pushRows(List<SyncRow> rows);

  /// Επιστρέφει όλες τις γραμμές που άλλαξαν μετά το [since] (ή όλες, αν
  /// [since] είναι null - πρώτος συγχρονισμός).
  Future<List<SyncRow>> pullRows(DateTime? since);

  /// Ένα ελαφρύ round-trip για να επαληθεύσουμε ότι τα στοιχεία σύνδεσης
  /// είναι σωστά, πριν αποθηκεύσουμε τις ρυθμίσεις σαν "λειτουργικές".
  Future<void> testConnection();
}

class SyncBackendException implements Exception {
  final String message;
  const SyncBackendException(this.message);
  @override
  String toString() => message;
}
