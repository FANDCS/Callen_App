import '../models/call_entry.dart';
import 'calls_service.dart';




class CallsServiceStub implements CallsService {
  @override
  Future<bool> requestPermissions() async => false;

  @override
  Future<List<CallEntry>> getCallLog({int? limit}) async => [];

  @override
  Future<void> placeCall(String phoneNumber) async {
    throw UnsupportedError(
      'Οι κλήσεις υποστηρίζονται μόνο στο Android σε αυτή την εφαρμογή.',
    );
  }
}
