/// Μία γραμμή όπως αποθηκεύεται/διαβάζεται από το backend (Supabase ή
/// PocketBase). Το [payload] είναι ΠΑΝΤΑ το κρυπτογραφημένο blob - ποτέ το
/// αρχικό CallEntry σε καθαρό κείμενο.
class SyncRow {
  final String entryId; // σταθερό id του CallEntry (uuid v4)
  final String deviceOrigin; // ποια συσκευή το δημιούργησε (καθαρό κείμενο)
  final String payload; // κρυπτογραφημένο blob (base64)
  final DateTime updatedAt; // πότε ανέβηκε/ενημερώθηκε - χρησιμοποιείται ως cursor

  const SyncRow({
    required this.entryId,
    required this.deviceOrigin,
    required this.payload,
    required this.updatedAt,
  });
}
