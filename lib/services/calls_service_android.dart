import 'package:call_log/call_log.dart' as native;
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import '../models/call_entry.dart';
import 'calls_service.dart';

class CallsServiceAndroid implements CallsService {
  final String deviceId; // περνιέται από το app κατά την αρχικοποίηση
  final _uuid = const Uuid();

  CallsServiceAndroid({required this.deviceId});

  @override
  Future<bool> requestPermissions() async {
    final statuses = await [
      Permission.phone, // καλύπτει το READ_CALL_LOG (ίδια permission group)
      Permission.contacts,
    ].request();

    return statuses.values.every((s) => s.isGranted);
  }

  @override
  Future<List<CallEntry>> getCallLog({int? limit}) async {
    final Iterable<native.CallLogEntry> entries = await native.CallLog.get();

    final result = entries.map((e) {
      return CallEntry(
        id: _uuid.v4(),
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

    if (limit != null && result.length > limit) {
      return result.sublist(0, limit);
    }
    return result;
  }

  @override
  Future<void> placeCall(String phoneNumber) async {
    // Ρητό αίτημα CALL_PHONE εδώ (δεν εμπιστευόμαστε αποκλειστικά το
    // εσωτερικό permission handling του plugin) — αν δεν είναι granted
    // τη στιγμή της κλήσης, το Android/plugin μπορεί να κάνει fallback
    // σε γενικό "Άνοιγμα με..." chooser αντί για απευθείας κλήση.
    final status = await Permission.phone.request();
    if (!status.isGranted) {
      throw Exception('Δεν δόθηκε άδεια κλήσης (CALL_PHONE).');
    }

    // ACTION_CALL: η κλήση ξεκινάει απευθείας από εδώ, με ένα πάτημα.
    // Αμέσως μετά, η οθόνη ενεργής κλήσης που εμφανίζεται είναι πάντα
    // της προεπιλεγμένης εφαρμογής τηλεφώνου της συσκευής (π.χ.
    // Samsung Phone app) — αυτό γίνεται αυτόματα από το ίδιο το
    // Android, ανεξάρτητα ποια εφαρμογή ξεκίνησε την κλήση. Δεν
    // χρειάζεται δικό μας InCallService για αυτό.
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
