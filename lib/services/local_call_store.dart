import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../models/call_entry.dart';

/// Τοπική μόνιμη αποθήκευση του ιστορικού κλήσεων.
///
/// Πριν το sync, το Android διάβαζε το native call log ζωντανά σε κάθε
/// φόρτωση της οθόνης και έδινε ΝΕΟ τυχαίο id σε κάθε εγγραφή - άρα δεν
/// υπήρχε σταθερή ταυτότητα να συγχρονιστεί. Αυτό το store γίνεται η
/// "πηγή αλήθειας": το Android κάνει merge το native call log εδώ μέσα
/// (δίνοντας σταθερό id μία φορά ανά πραγματική κλήση), και το Linux
/// (που δεν έχει καθόλου native call log) διαβάζει αποκλειστικά από εδώ -
/// δηλαδή μόνο ό,τι έχει έρθει μέσω sync από το Android.
class LocalCallStore {
  static const _dbName = 'callen_local.db';
  static const _table = 'call_entries';
  final _uuid = const Uuid();

  Database? _db;

  Future<Database> _database() async {
    if (_db != null) return _db!;
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_table (
            id TEXT PRIMARY KEY,
            phone_number TEXT NOT NULL,
            contact_name TEXT,
            type TEXT NOT NULL,
            timestamp_ms INTEGER NOT NULL,
            duration_seconds INTEGER NOT NULL,
            device_origin TEXT NOT NULL,
            synced INTEGER NOT NULL DEFAULT 0,
            natural_key TEXT
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_call_entries_natural_key ON $_table(natural_key)',
        );
        await db.execute(
          'CREATE INDEX idx_call_entries_timestamp ON $_table(timestamp_ms)',
        );
      },
    );
    return _db!;
  }

  /// Ένα "φυσικό κλειδί" από τα ίδια τα δεδομένα της κλήσης (χωρίς να
  /// υπάρχει σταθερό id από το native call log), ώστε να ξέρουμε αν μια
  /// εγγραφή που μόλις διαβάσαμε από το Android υπάρχει ήδη τοπικά ή είναι
  /// καινούρια.
  String _naturalKey(CallEntry e) =>
      '${e.deviceOrigin}|${e.phoneNumber}|${e.timestamp.millisecondsSinceEpoch}|${e.duration.inSeconds}|${e.type.name}';

  /// Καλείται ΜΟΝΟ από το Android: παίρνει ό,τι μόλις διάβασε από το
  /// native call log, κάνει merge με ό,τι υπάρχει ήδη τοπικά (δίνοντας
  /// σταθερό id στις πραγματικά καινούριες), και επιστρέφει ΟΛΕΣ τις
  /// εγγραφές (native + όσες έχουν έρθει από sync) ταξινομημένες.
  Future<List<CallEntry>> mergeFromNative(List<CallEntry> nativeEntries) async {
    final db = await _database();
    await db.transaction((txn) async {
      for (final e in nativeEntries) {
        final key = _naturalKey(e);
        final existing = await txn.query(
          _table,
          where: 'natural_key = ?',
          whereArgs: [key],
          limit: 1,
        );
        if (existing.isNotEmpty) continue; // ήδη γνωστή κλήση, δεν ξανά-μπαίνει
        await txn.insert(
          _table,
          _toRow(e, key, id: _uuid.v4()),
        );
      }
    });
    return getAll();
  }

  Future<List<CallEntry>> getAll({int? limit}) async {
    final db = await _database();
    final rows = await db.query(
      _table,
      orderBy: 'timestamp_ms DESC',
      limit: limit,
    );
    return rows.map(_fromRow).toList();
  }

  Future<List<CallEntry>> getUnsynced() async {
    final db = await _database();
    final rows = await db.query(_table, where: 'synced = 0');
    return rows.map(_fromRow).toList();
  }

  Future<void> markSynced(Iterable<String> ids) async {
    if (ids.isEmpty) return;
    final db = await _database();
    final placeholders = List.filled(ids.length, '?').join(',');
    await db.update(
      _table,
      {'synced': 1},
      where: 'id IN ($placeholders)',
      whereArgs: ids.toList(),
    );
  }

  /// Καλείται όταν φτάνει μια εγγραφή από sync (δηλ. δημιουργήθηκε σε
  /// ΑΛΛΗ συσκευή). Idempotent με βάση το id: αν την ξέρουμε ήδη, δεν
  /// κάνουμε τίποτα.
  Future<void> insertFromRemote(CallEntry e) async {
    final db = await _database();
    final key = _naturalKey(e);
    await db.insert(
      _table,
      _toRow(e, key)..['synced'] = 1,
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Map<String, Object?> _toRow(CallEntry e, String naturalKey, {String? id}) => {
        'id': id ?? e.id,
        'phone_number': e.phoneNumber,
        'contact_name': e.contactName,
        'type': e.type.name,
        'timestamp_ms': e.timestamp.millisecondsSinceEpoch,
        'duration_seconds': e.duration.inSeconds,
        'device_origin': e.deviceOrigin,
        'synced': e.synced ? 1 : 0,
        'natural_key': naturalKey,
      };

  CallEntry _fromRow(Map<String, Object?> row) => CallEntry(
        id: row['id'] as String,
        phoneNumber: row['phone_number'] as String,
        contactName: row['contact_name'] as String?,
        type: CallType.values.firstWhere(
          (t) => t.name == row['type'],
          orElse: () => CallType.unknown,
        ),
        timestamp: DateTime.fromMillisecondsSinceEpoch(row['timestamp_ms'] as int),
        duration: Duration(seconds: row['duration_seconds'] as int),
        deviceOrigin: row['device_origin'] as String,
        synced: (row['synced'] as int) == 1,
      );
}
