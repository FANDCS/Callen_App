import 'package:flutter/material.dart';
import '../models/call_entry.dart';
import '../services/calls_service.dart';
import '../services/contacts_service.dart';
import '../services/settings_store.dart';
import '../theme/app_theme.dart';
import '../utils/app_strings.dart';
import '../utils/phone_utils.dart';

class CallLogScreen extends StatefulWidget {
  final CallsService callsService;
  final ContactsService contactsService;
  final AppStrings strings;
  final SettingsStore store;
  const CallLogScreen({
    super.key,
    required this.callsService,
    required this.contactsService,
    required this.strings,
    required this.store,
  });

  @override
  State<CallLogScreen> createState() => _CallLogScreenState();
}

class _CallLogScreenState extends State<CallLogScreen> {
  List<CallEntry> _entries = [];
  bool _loading = true;
  bool _permissionGranted = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final callsGranted = await widget.callsService.requestPermissions();
    if (!callsGranted) {
      setState(() {
        _permissionGranted = false;
        _loading = false;
      });
      return;
    }

    final contactsGranted = await widget.contactsService.requestPermission();
    final Map<String, String> nameByNumber = {};
    if (contactsGranted) {
      final contacts = await widget.contactsService.getContacts(
        sourceIds: widget.store.contactSources,
      );
      for (final c in contacts) {
        for (final phone in c.phoneNumbers) {
          nameByNumber[normalizedPhoneKey(phone)] = c.displayName;
        }
      }
    }

    final rawEntries = await widget.callsService.getCallLog();
    final entries = rawEntries.map((e) {
      if (e.contactName != null && e.contactName!.isNotEmpty) return e;
      final match = nameByNumber[normalizedPhoneKey(e.phoneNumber)];
      if (match == null) return e;
      return e.copyWith(contactName: match);
    }).toList();

    if (!mounted) return;
    setState(() {
      _permissionGranted = true;
      _entries = entries;
      _loading = false;
    });
  }

  String _semanticType(CallType type) {
    switch (type) {
      case CallType.incoming:
        return 'incoming';
      case CallType.outgoing:
        return 'outgoing';
      case CallType.missed:
        return 'missed';
      case CallType.rejected:
      case CallType.blocked:
        return 'blocked';
      case CallType.unknown:
        return 'blocked';
    }
  }

  IconData _iconFor(CallType type) {
    switch (type) {
      case CallType.incoming:
        return Icons.call_received;
      case CallType.outgoing:
        return Icons.call_made;
      case CallType.missed:
        return Icons.call_missed;
      case CallType.rejected:
      case CallType.blocked:
        return Icons.block;
      case CallType.unknown:
        return Icons.call;
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatWhen(DateTime dt) {
    final local = dt.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final thatDay = DateTime(local.year, local.month, local.day);
    final time =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';

    if (thatDay == today) return '${widget.strings.today}, $time';
    if (thatDay == today.subtract(const Duration(days: 1))) {
      return '${widget.strings.yesterday}, $time';
    }
    return '${local.day}/${local.month}/${local.year}, $time';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_permissionGranted) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          children: [
            const SizedBox(height: 120),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  widget.strings.callLogPermissionNeeded,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_entries.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          children: [
            const SizedBox(height: 120),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  widget.strings.callLogEmpty,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        // cacheExtent μεγαλύτερο ώστε να προ-χτίζονται λίγα items πριν
        // μπουν στην οθόνη — μειώνει το jank κατά το scroll.
        cacheExtent: 800,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _entries.length,
        itemBuilder: (context, index) {
          final e = _entries[index];
          final semantic = _semanticType(e.type);
          final color = AppTheme.callTypeColor(semantic);
          final isMissed = e.type == CallType.missed;

          // RepaintBoundary: απομονώνει κάθε γραμμή σε δικό της layer,
          // ώστε το scroll να μη ζωγραφίζει ξανά ολόκληρη τη λίστα σε
          // κάθε frame — αισθητά πιο ομαλό scroll σε μεγάλες λίστες.
          return RepaintBoundary(
            child: Card(
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                leading: CircleAvatar(
                  radius: 22,
                  backgroundColor: color.withValues(alpha: 0.14),
                  child: Icon(_iconFor(e.type), color: color, size: 22),
                ),
                title: Text(
                  e.contactName ?? e.phoneNumber,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isMissed ? AppColors.missed : null,
                  ),
                ),
                subtitle: Text(
                  '${_formatWhen(e.timestamp)} · ${_formatDuration(e.duration)}',
                ),
                trailing: IconButton.filledTonal(
                  icon: const Icon(Icons.call),
                  onPressed: () =>
                      widget.callsService.placeCall(e.phoneNumber),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
