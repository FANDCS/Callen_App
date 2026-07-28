import '../models/call_entry.dart';

/// Interface για πρόσβαση στο ιστορικό κλήσεων και για την
/// πραγματοποίηση κλήσεων. Έχει μόνο μία πραγματική υλοποίηση
/// (Android), αλλά κρατάμε το interface ξεχωριστό ώστε:
/// - Να μπορούμε αργότερα να προσθέσουμε VoIP/SIP υλοποίηση χωρίς
///   να αλλάξει τίποτα στο UI.
/// - Να μπορούμε να κάνουμε mock/test χωρίς πραγματική συσκευή.
abstract class CallsService {
  /// Ζητάει τα απαραίτητα runtime permissions (READ_CALL_LOG, CALL_PHONE).
  /// Επιστρέφει true αν όλα δόθηκαν.
  Future<bool> requestPermissions();

  /// Διαβάζει το ιστορικό κλήσεων από τη συσκευή.
  Future<List<CallEntry>> getCallLog({int? limit});

  /// Ξεκινάει κλήση προς τον δοθέντα αριθμό (ανοίγει το system dialer
  /// UI ή καλεί απευθείας, ανάλογα με τα permissions).
  Future<void> placeCall(String phoneNumber);
}
