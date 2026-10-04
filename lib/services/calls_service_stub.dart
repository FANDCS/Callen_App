import '../models/call_entry.dart';
import '../services/local_call_store.dart';
import 'calls_service.dart';

class CallsServiceStub implements CallsService {
  final LocalCallStore localStore;
  CallsServiceStub({required this.localStore});

  @override
  Future<bool> requestPermissions() async => false;

  @override
  Future<List<CallEntry>> getCallLog({int? limit}) => localStore.getAll(limit: limit);

  @override
  Future<void> placeCall(String phoneNumber) async {}

  @override
  Future<void> deleteEntry(String id) => localStore.delete(id);
}
