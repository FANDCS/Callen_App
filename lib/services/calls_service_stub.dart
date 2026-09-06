import '../models/call_entry.dart';
import 'calls_service.dart';
import 'local_call_store.dart';

/// Χρησιμοποιείται σε Linux/Windows. Δεν υπάρχει native call log σε αυτές
/// τις πλατφόρμες - το ιστορικό εδώ προέρχεται ΑΠΟΚΛΕΙΣΤΙΚΑ από sync
/// (δηλ. ό,τι έστειλε το Android). Χωρίς ενεργό συγχρονισμό, η λίστα
/// παραμένει κενή, κάτι που είναι αναμενόμενο (όχι σφάλμα άδειας).
class CallsServiceStub implements CallsService {
  final LocalCallStore localStore;

  CallsServiceStub({required this.localStore});

  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<List<CallEntry>> getCallLog({int? limit}) =>
      localStore.getAll(limit: limit);

  @override
  Future<void> placeCall(String phoneNumber) async {
    throw UnsupportedError(
      'Οι κλήσεις υποστηρίζονται μόνο στο Android σε αυτή την εφαρμογή.',
    );
  }
}
