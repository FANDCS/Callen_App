import '../models/call_entry.dart';







abstract class CallsService {
  
  
  Future<bool> requestPermissions();

  
  Future<List<CallEntry>> getCallLog({int? limit});

  
  
  Future<void> placeCall(String phoneNumber);
}
