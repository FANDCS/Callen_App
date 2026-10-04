import '../models/call_entry.dart';

abstract class CallsService {
  Future<bool> requestPermissions();
  Future<List<CallEntry>> getCallLog({int? limit});
  /// Entries already stored locally (fast, no system call-log read).
  Future<List<CallEntry>> getCachedCallLog();
  Future<void> placeCall(String phoneNumber);
  Future<void> deleteEntry(String id);
}
