import 'package:flutter/material.dart';
import 'package:call_log/call_log.dart' as native;
import '../models/call_entry.dart';
import '../services/calls_service.dart';
import '../services/contacts_service.dart';
import '../services/settings_store.dart';
import '../theme/app_theme.dart';
import '../utils/app_strings.dart';
import '../utils/phone_utils.dart';

enum _Filter { all, missed, incoming, outgoing, rejected }

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

  final _searchController = TextEditingController();
  String _searchQuery = '';
  _Filter _filter = _Filter.all;
  bool _searchVisible = false;

  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final callsGranted = await widget.callsService.requestPermissions();
    if (!callsGranted) {
      if (!mounted) return;
      setState(() { _permissionGranted = false; _loading = false; });
      return;
    }

    final rawEntries = await widget.callsService.getCallLog();
    if (!mounted) return;
    setState(() { _entries = rawEntries; _loading = false; });

    // Enrich with contact names in background
    final contactsGranted = await widget.contactsService.requestPermission();
    if (!contactsGranted || !mounted) return;

    final contacts = await widget.contactsService.getContacts(
      sourceIds: widget.store.contactSources,
    );
    final nameByNumber = <String, String>{};
    for (final c in contacts) {
      for (final phone in c.phoneNumbers) {
        nameByNumber[normalizedPhoneKey(phone.number)] = c.displayName;
      }
    }

    final enriched = rawEntries.map((e) {
      if (e.contactName != null && e.contactName!.isNotEmpty) return e;
      final match = nameByNumber[normalizedPhoneKey(e.phoneNumber)];
      return match == null ? e : e.copyWith(contactName: match);
    }).toList();

    if (!mounted) return;
    setState(() => _entries = enriched);
  }

  // ── delete ────────────────────────────────────────────────────────────────

  Future<void> _deleteEntry(CallEntry e) async {
    final s = widget.strings;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.deleteCallTitle),
        content: Text(s.deleteCallConfirm(e.contactName ?? e.phoneNumber)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(s.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final deleteFromAndroid = widget.store.deleteFromAndroid;

    if (deleteFromAndroid) {
      // Delete from Android call log by timestamp + number
      try {
        final entries = await native.CallLog.get(
          dateFrom: e.timestamp.millisecondsSinceEpoch - 1000,
          dateTo: e.timestamp.millisecondsSinceEpoch + 1000,
        );
        for (final ne in entries) {
          if (ne.number == e.phoneNumber) {
            await native.CallLog.delete(ne.timestamp!);
            break;
          }
        }
      } catch (_) {}
    }

    // Always remove from local store
    await widget.callsService.deleteEntry(e.id);
    if (!mounted) return;
    setState(() => _entries.removeWhere((x) => x.id == e.id));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(s.callDeleted)),
    );
  }

  // ── confirm international call ────────────────────────────────────────────

  Future<void> _placeCallWithCheck(String number) async {
    if (widget.store.confirmIntlCalls && _isInternational(number)) {
      final s = widget.strings;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(s.confirmIntlCallTitle),
          content: Text(s.confirmIntlCallBody(number)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(s.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(s.call),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    await widget.callsService.placeCall(number);
  }

  bool _isInternational(String number) {
    final digits = number.replaceAll(RegExp(r'[^\d+]'), '');
    return digits.startsWith('+') && !digits.startsWith('+30');
  }

  // ── filtering ─────────────────────────────────────────────────────────────

  List<CallEntry> get _visible {
    var list = _entries;
    switch (_filter) {
      case _Filter.missed:
        list = list.where((e) => e.type == CallType.missed).toList();
      case _Filter.incoming:
        list = list.where((e) => e.type == CallType.incoming).toList();
      case _Filter.outgoing:
        list = list.where((e) => e.type == CallType.outgoing).toList();
      case _Filter.rejected:
        list = list.where((e) =>
            e.type == CallType.rejected || e.type == CallType.blocked).toList();
      case _Filter.all:
        break;
    }
    if (_searchQuery.isNotEmpty) {
      list = list.where((e) {
        final name = (e.contactName ?? '').toLowerCase();
        final num  = e.phoneNumber.toLowerCase();
        return name.contains(_searchQuery) || num.contains(_searchQuery);
      }).toList();
    }
    return list;
  }

  // ── group by date ─────────────────────────────────────────────────────────

  List<Object> _grouped(List<CallEntry> entries) {
    final result = <Object>[];
    DateTime? lastDay;
    for (final e in entries) {
      final local = e.timestamp.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      if (lastDay == null || day != lastDay) {
        result.add(day);
        lastDay = day;
      }
      result.add(e);
    }
    return result;
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  String _semanticType(CallType type) {
    switch (type) {
      case CallType.incoming: return 'incoming';
      case CallType.outgoing: return 'outgoing';
      case CallType.missed:   return 'missed';
      case CallType.rejected:
      case CallType.blocked:
      case CallType.unknown:  return 'blocked';
    }
  }

  IconData _iconFor(CallType type) {
    switch (type) {
      case CallType.incoming: return Icons.call_received;
      case CallType.outgoing: return Icons.call_made;
      case CallType.missed:   return Icons.call_missed;
      case CallType.rejected:
      case CallType.blocked:  return Icons.block;
      case CallType.unknown:  return Icons.call;
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _formatTime(DateTime dt) {
    final l = dt.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }

  static const _monthNamesEl = [
    '', 'Ιανουαρίου', 'Φεβρουαρίου', 'Μαρτίου', 'Απριλίου',
    'Μαΐου', 'Ιουνίου', 'Ιουλίου', 'Αυγούστου',
    'Σεπτεμβρίου', 'Οκτωβρίου', 'Νοεμβρίου', 'Δεκεμβρίου',
  ];
  static const _monthNamesEn = [
    '', 'January', 'February', 'March', 'April',
    'May', 'June', 'July', 'August',
    'September', 'October', 'November', 'December',
  ];

  String _formatDayHeader(DateTime day) {
    final s = widget.strings;
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (day == today) return s.today;
    if (day == today.subtract(const Duration(days: 1))) return s.yesterday;
    final isGreek = s.lang == AppLanguage.greek;
    final months  = isGreek ? _monthNamesEl : _monthNamesEn;
    return isGreek
        ? '${day.day} ${months[day.month]} ${day.year}'
        : '${months[day.month]} ${day.day}, ${day.year}';
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;

    if (_loading) return const Center(child: CircularProgressIndicator());
    if (!_permissionGranted) return _centeredMessage(s.callLogPermissionNeeded);

    final visible  = _visible;
    final grouped  = _grouped(visible);

    return Column(
      children: [
        // ── toolbar ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
          child: Row(
            children: [
              Expanded(
                child: _searchVisible
                    ? TextField(
                        controller: _searchController,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: s.searchCallLog,
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchVisible = false);
                            },
                          ),
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 16),
                        ),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(children: [
                          _Chip(label: s.filterAll,
                              selected: _filter == _Filter.all,
                              onTap: () => setState(() => _filter = _Filter.all)),
                          const SizedBox(width: 6),
                          _Chip(label: s.filterMissed,
                              selected: _filter == _Filter.missed,
                              onTap: () => setState(() => _filter = _Filter.missed)),
                          const SizedBox(width: 6),
                          _Chip(label: s.filterIncoming,
                              selected: _filter == _Filter.incoming,
                              onTap: () => setState(() => _filter = _Filter.incoming)),
                          const SizedBox(width: 6),
                          _Chip(label: s.filterOutgoing,
                              selected: _filter == _Filter.outgoing,
                              onTap: () => setState(() => _filter = _Filter.outgoing)),
                          const SizedBox(width: 6),
                          _Chip(label: s.filterRejected,
                              selected: _filter == _Filter.rejected,
                              onTap: () => setState(() => _filter = _Filter.rejected)),
                        ]),
                      ),
              ),
              if (!_searchVisible)
                IconButton(
                  icon: const Icon(Icons.search),
                  tooltip: s.searchCallLog,
                  onPressed: () => setState(() => _searchVisible = true),
                ),
            ],
          ),
        ),

        // ── list ─────────────────────────────────────────────────────────
        Expanded(
          child: visible.isEmpty
              ? _centeredMessage(
                  _searchQuery.isNotEmpty || _filter != _Filter.all
                      ? s.callLogNoResults
                      : s.callLogEmpty,
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: Scrollbar(
                    controller: _scrollController,
                    interactive: true,       // <-- allows dragging the thumb
                    thumbVisibility: true,
                    thickness: 6,
                    radius: const Radius.circular(3),
                    child: ListView.builder(
                      controller: _scrollController,
                      cacheExtent: 800,
                      physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics()),
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: grouped.length,
                      itemBuilder: (context, index) {
                        final item = grouped[index];

                        // ── date header ──────────────────────────────────
                        if (item is DateTime) {
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                            child: Text(
                              _formatDayHeader(item),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                                letterSpacing: 0.4,
                              ),
                            ),
                          );
                        }

                        // ── call row ─────────────────────────────────────
                        final e       = item as CallEntry;
                        final semantic = _semanticType(e.type);
                        final color   = AppTheme.callTypeColor(semantic);
                        final isMissed = e.type == CallType.missed;

                        return RepaintBoundary(
                          child: Dismissible(
                            key: ValueKey(e.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              color: Colors.red,
                              child: const Icon(Icons.delete_outline,
                                  color: Colors.white),
                            ),
                            confirmDismiss: (_) async {
                              await _deleteEntry(e);
                              return false; // we handle removal ourselves
                            },
                            child: Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 4),
                                leading: CircleAvatar(
                                  radius: 22,
                                  backgroundColor: color.withValues(alpha: 0.14),
                                  child: Icon(_iconFor(e.type),
                                      color: color, size: 22),
                                ),
                                title: Text(
                                  e.contactName ?? e.phoneNumber,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: isMissed ? AppColors.missed : null,
                                  ),
                                ),
                                subtitle: Text(
                                  '${_formatTime(e.timestamp)} · '
                                  '${_formatDuration(e.duration)}',
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton.filledTonal(
                                      icon: const Icon(Icons.call),
                                      onPressed: () =>
                                          _placeCallWithCheck(e.phoneNumber),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          size: 20),
                                      color: Colors.red,
                                      tooltip: s.delete,
                                      onPressed: () => _deleteEntry(e),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _centeredMessage(String msg) => RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics()),
          children: [
            const SizedBox(height: 120),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(msg, textAlign: TextAlign.center),
              ),
            ),
          ],
        ),
      );
}

// ── filter chip ───────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primary
              : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
