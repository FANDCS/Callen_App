/// Αντιπροσωπεύει μία εγγραφή στο ιστορικό κλήσεων.
/// Αυτό το model θα είναι αργότερα κοινό (ή παρόμοιο) με ό,τι
/// χρησιμοποιεί το shared-sync-core για το sync στο OneDrive.
enum CallType { incoming, outgoing, missed, rejected, blocked, unknown }

class CallEntry {
  final String id; // uuid, δημιουργείται τοπικά όταν διαβάζουμε από το call_log
  final String phoneNumber;
  final String? contactName; // null αν ο αριθμός δεν αντιστοιχεί σε επαφή
  final CallType type;
  final DateTime timestamp;
  final Duration duration;
  final String deviceOrigin; // ποια συσκευή κατέγραψε την κλήση
  final bool synced; // αν έχει ήδη ανέβει στο OneDrive

  const CallEntry({
    required this.id,
    required this.phoneNumber,
    this.contactName,
    required this.type,
    required this.timestamp,
    required this.duration,
    required this.deviceOrigin,
    this.synced = false,
  });

  factory CallEntry.fromJson(Map<String, dynamic> json) => CallEntry(
        id: json['id'] as String,
        phoneNumber: json['phoneNumber'] as String,
        contactName: json['contactName'] as String?,
        type: CallType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => CallType.unknown,
        ),
        timestamp: DateTime.parse(json['timestamp'] as String),
        duration: Duration(seconds: json['durationSeconds'] as int),
        deviceOrigin: json['deviceOrigin'] as String,
        synced: json['synced'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'phoneNumber': phoneNumber,
        'contactName': contactName,
        'type': type.name,
        'timestamp': timestamp.toIso8601String(),
        'durationSeconds': duration.inSeconds,
        'deviceOrigin': deviceOrigin,
        'synced': synced,
      };

  CallEntry copyWith({bool? synced, String? contactName}) => CallEntry(
        id: id,
        phoneNumber: phoneNumber,
        contactName: contactName ?? this.contactName,
        type: type,
        timestamp: timestamp,
        duration: duration,
        deviceOrigin: deviceOrigin,
        synced: synced ?? this.synced,
      );
}
