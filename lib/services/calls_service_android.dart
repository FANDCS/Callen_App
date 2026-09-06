import 'package:call_log/call_log.dart' as native;
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/call_entry.dart';
import 'calls_service.dart';
import 'local_call_store.dart';

class CallsServiceAndroid implements CallsService {
  final String deviceId;
  final LocalCallStore localStore;

  CallsServiceAndroid({required this.deviceId, required this.localStore});

  @override
  Future<bool> requestPermissions() async {
    final statuses = await [
      Permission.phone, 
      Permission.contacts,
    ].request();

    return statuses.values.every((s) => s.isGranted);
  }

  @override
  Future<List<CallEntry>> getCallLog({int? limit}) async {
    final Iterable<native.CallLogEntry> entries = await native.CallLog.get();

    // Το native id δεν χρειάζεται να είναι σταθερό εδώ - το
    // LocalCallStore αναγνωρίζει τις πραγματικά καινούριες κλήσεις μέσω
    // "φυσικού κλειδιού" (αριθμός+ώρα+διάρκεια+τύπος) και δίνει το δικό
    // του σταθερό id μόνο σε αυτές. Έτσι η ίδια κλήση δεν "ξαναγεννιέται"
    // με άλλο id σε κάθε φόρτωση, πράγμα απαραίτητο για το sync.
    final nativeEntries = entries.map((e) {
      return CallEntry(
        id: '',
        phoneNumber: e.number ?? 'unknown',
        contactName: e.name,
        type: _mapCallType(e.callType),
        timestamp: DateTime.fromMillisecondsSinceEpoch(
          e.timestamp ?? 0,
        ),
        duration: Duration(seconds: e.duration ?? 0),
        deviceOrigin: deviceId,
      );
    }).toList();

    final merged = await localStore.mergeFromNative(nativeEntries);
    if (limit != null && merged.length > limit) {
      return merged.sublist(0, limit);
    }
    return merged;
  }

  @override
  Future<void> placeCall(String phoneNumber) async {
    
    
    
    
    final status = await Permission.phone.request();
    if (!status.isGranted) {
      throw Exception('Δεν δόθηκε άδεια κλήσης (CALL_PHONE).');
    }

    
    
    
    
    
    
    final success = await FlutterPhoneDirectCaller.callNumber(phoneNumber);
    if (success != true) {
      throw Exception('Δεν ήταν δυνατή η εκκίνηση κλήσης προς $phoneNumber');
    }
  }

  CallType _mapCallType(native.CallType? type) {
    switch (type) {
      case native.CallType.incoming:
        return CallType.incoming;
      case native.CallType.outgoing:
        return CallType.outgoing;
      case native.CallType.missed:
        return CallType.missed;
      case native.CallType.rejected:
        return CallType.rejected;
      case native.CallType.blocked:
        return CallType.blocked;
      default:
        return CallType.unknown;
    }
  }
}
