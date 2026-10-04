import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/call_entry.dart';
import '../services/calls_service.dart';
import '../services/contacts_service.dart';
import '../services/settings_store.dart';
import '../theme/app_theme.dart';
import '../utils/app_strings.dart';
import '../utils/phone_utils.dart';

// ── Greek area code → city ────────────────────────────────────────────────────
const _grPrefixEl = {
  // Αττική
  '210': 'Αθήνα', '211': 'Αθήνα', '212': 'Αθήνα', '213': 'Αθήνα',
  '214': 'Αθήνα', '215': 'Αθήνα', '216': 'Αθήνα',
  // Θεσσαλονίκη
  '2310': 'Θεσσαλονίκη', '2311': 'Θεσσαλονίκη', '2312': 'Θεσσαλονίκη', '2313': 'Θεσσαλονίκη',
  // Θεσσαλία
  '2410': 'Λάρισα', '2411': 'Λάρισα',
  '24210': 'Βόλος', '24220': 'Αλμυρός',
  '24310': 'Τρίκαλα', '24410': 'Καρδίτσα',
  // Κεντρ. Μακεδονία
  '2321': 'Βέροια', '2331': 'Νάουσα', '2351': 'Κατερίνη',
  '2371': 'Σέρρες', '2381': 'Κιλκίς', '2391': 'Γιαννιτσά',
  '23210': 'Έδεσσα',
  // Δυτ. Μακεδονία
  '23310': 'Φλώρινα', '23510': 'Κοζάνη', '23610': 'Πτολεμαΐδα',
  '23710': 'Γρεβενά', '23820': 'Καστοριά',
  // Ανατ. Μακεδονία - Θράκη
  '2510': 'Καβάλα', '2521': 'Δράμα', '2531': 'Ξάνθη',
  '2541': 'Κομοτηνή', '2551': 'Αλεξανδρούπολη',
  // Ήπειρος
  '26510': 'Ιωάννινα', '26550': 'Άρτα', '26650': 'Λευκάδα',
  // Ιόνια Νησιά
  '26610': 'Κέρκυρα',
  // Δυτ. Ελλάδα
  '2610': 'Πάτρα', '2611': 'Πάτρα', '2612': 'Πάτρα',
  '26210': 'Αγρίνιο', '26310': 'Μεσολόγγι', '26910': 'Πύργος',
  // Στερεά Ελλάδα
  '22310': 'Λαμία', '22610': 'Χαλκίδα', '22650': 'Λειβαδιά',
  // Πελοπόννησος
  '27210': 'Καλαμάτα', '27310': 'Σπάρτη', '27410': 'Τρίπολη',
  '27420': 'Άργος', '27520': 'Ναύπλιο', '27610': 'Κόρινθος',
  // Κρήτη
  '2810': 'Ηράκλειο', '2811': 'Ηράκλειο',
  '2821': 'Χανιά', '2831': 'Ρέθυμνο', '2841': 'Άγιος Νικόλαος',
  // Νησιά Αιγαίου
  '22410': 'Ρόδος', '22460': 'Κως', '22730': 'Χίος', '22510': 'Μυτιλήνη',
  '22890': 'Μύκονος', '22860': 'Σαντορίνη', '22840': 'Πάρος',
  '22850': 'Νάξος', '22810': 'Σύρος', '22980': 'Αίγινα',
};

const _grPrefixEn = {
  '210': 'Athens', '211': 'Athens', '212': 'Athens', '213': 'Athens',
  '214': 'Athens', '215': 'Athens', '216': 'Athens',
  '2310': 'Thessaloniki', '2311': 'Thessaloniki', '2312': 'Thessaloniki', '2313': 'Thessaloniki',
  '2410': 'Larissa', '2411': 'Larissa',
  '24210': 'Volos', '24220': 'Almyros', '24310': 'Trikala', '24410': 'Karditsa',
  '2321': 'Veria', '2351': 'Katerini', '2371': 'Serres',
  '23510': 'Kozani', '23610': 'Ptolemaida', '23820': 'Kastoria',
  '2510': 'Kavala', '2521': 'Drama', '2531': 'Xanthi',
  '2541': 'Komotini', '2551': 'Alexandroupoli',
  '26510': 'Ioannina', '26550': 'Arta', '26650': 'Lefkada',
  '26610': 'Corfu',
  '2610': 'Patras', '2611': 'Patras', '2612': 'Patras',
  '26210': 'Agrinio', '26310': 'Messolonghi', '26910': 'Pyrgos',
  '22310': 'Lamia', '22610': 'Chalkida', '22650': 'Livadeia',
  '27210': 'Kalamata', '27310': 'Sparta', '27410': 'Tripoli',
  '27420': 'Argos', '27520': 'Nafplio', '27610': 'Corinth',
  '2810': 'Heraklion', '2811': 'Heraklion',
  '2821': 'Chania', '2831': 'Rethymno', '2841': 'Agios Nikolaos',
  '22410': 'Rhodes', '22460': 'Kos', '22730': 'Chios', '22510': 'Mytilene',
  '22890': 'Mykonos', '22860': 'Santorini', '22840': 'Paros',
  '22850': 'Naxos', '22810': 'Syros', '22980': 'Aegina',
};

const _countryCodes = {
  '+1': 'USA/Canada', '+7': 'Russia', '+20': 'Egypt',
  '+27': 'South Africa', '+30': 'Greece', '+31': 'Netherlands',
  '+32': 'Belgium', '+33': 'France', '+34': 'Spain',
  '+36': 'Hungary', '+39': 'Italy', '+40': 'Romania',
  '+41': 'Switzerland', '+43': 'Austria', '+44': 'UK',
  '+45': 'Denmark', '+46': 'Sweden', '+47': 'Norway',
  '+48': 'Poland', '+49': 'Germany', '+51': 'Peru',
  '+52': 'Mexico', '+53': 'Cuba', '+54': 'Argentina',
  '+55': 'Brazil', '+56': 'Chile', '+57': 'Colombia',
  '+58': 'Venezuela', '+60': 'Malaysia', '+61': 'Australia',
  '+62': 'Indonesia', '+63': 'Philippines', '+64': 'New Zealand',
  '+65': 'Singapore', '+66': 'Thailand', '+81': 'Japan',
  '+82': 'South Korea', '+84': 'Vietnam', '+86': 'China',
  '+90': 'Turkey', '+91': 'India', '+92': 'Pakistan',
  '+94': 'Sri Lanka', '+98': 'Iran', '+212': 'Morocco',
  '+213': 'Algeria', '+216': 'Tunisia', '+234': 'Nigeria',
  '+254': 'Kenya', '+351': 'Portugal', '+352': 'Luxembourg',
  '+353': 'Ireland', '+354': 'Iceland', '+355': 'Albania',
  '+356': 'Malta', '+357': 'Cyprus', '+358': 'Finland',
  '+359': 'Bulgaria', '+370': 'Lithuania', '+371': 'Latvia',
  '+372': 'Estonia', '+380': 'Ukraine', '+381': 'Serbia',
  '+385': 'Croatia', '+386': 'Slovenia', '+387': 'Bosnia',
  '+389': 'North Macedonia', '+420': 'Czech Republic', '+421': 'Slovakia',
  '+852': 'Hong Kong', '+880': 'Bangladesh', '+886': 'Taiwan',
  '+961': 'Lebanon', '+962': 'Jordan', '+964': 'Iraq',
  '+965': 'Kuwait', '+966': 'Saudi Arabia', '+971': 'UAE',
  '+972': 'Israel', '+974': 'Qatar', '+994': 'Azerbaijan',
  '+995': 'Georgia', '+998': 'Uzbekistan',
};

enum _Filter { all, missed, incoming, outgoing, rejected, international, local }

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
  final Set<_Filter> _activeFilters = {_Filter.all};
  bool _searchVisible = false;
  final _scrollController = ScrollController();
  final Set<String> _selected = {};
  bool get _selecting => _selected.isNotEmpty;

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

  Future<void> _deleteEntries(List<CallEntry> toDelete) async {
    final s = widget.strings;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.deleteCallTitle),
        content: Text(toDelete.length == 1
            ? s.deleteCallConfirm(toDelete.first.contactName ?? toDelete.first.phoneNumber)
            : s.deleteCallConfirmMultiple(toDelete.length)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(s.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    if (widget.store.deleteFromAndroid) {
      for (final e in toDelete) {
        try {
          final ch = MethodChannel('gr.fandcs.callen/calllog');
          await ch.invokeMethod('deleteEntry', {
            'number': e.phoneNumber,
            'timestampMs': e.timestamp.millisecondsSinceEpoch,
          });
        } catch (_) {}
      }
    }
    for (final e in toDelete) {
      await widget.callsService.deleteEntry(e.id);
    }
    if (!mounted) return;
    final ids = toDelete.map((e) => e.id).toSet();
    setState(() {
      _entries.removeWhere((e) => ids.contains(e.id));
      _selected.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(s.callDeleted)),
    );
  }

  // ── international call confirm ────────────────────────────────────────────

  Future<void> _placeCallWithCheck(String number) async {
    if (widget.store.confirmIntlCalls && _isInternational(number)) {
      final s = widget.strings;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(s.confirmIntlCallTitle),
          content: Text(s.confirmIntlCallBody(number)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.call)),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    await widget.callsService.placeCall(number);
  }

  bool _isInternational(String number) {
    final d = number.replaceAll(RegExp(r'[^\d+]'), '');
    return d.startsWith('+') && !d.startsWith('+30');
  }

  // ── phone info ────────────────────────────────────────────────────────────

  void _showPhoneInfo(BuildContext context, CallEntry e) {
    final s = widget.strings;
    final isGreek = s.lang == AppLanguage.greek;
    final number = e.phoneNumber.replaceAll(RegExp(r'[\s\-()]'), '');
    String? origin;
    String type;

    if (number.startsWith('+30') || (!number.startsWith('+') && number.startsWith('2'))) {
      final local = number.startsWith('+30') ? number.substring(3) : number;
      final prefixMap = isGreek ? _grPrefixEl : _grPrefixEn;
      for (int len = 5; len >= 3; len--) {
        if (local.length >= len) {
          final key = local.substring(0, len);
          if (prefixMap.containsKey(key)) { origin = prefixMap[key]; break; }
        }
      }
      if (origin == null && local.startsWith('21')) origin = isGreek ? 'Αθήνα' : 'Athens';
      type = isGreek ? 'Σταθερό (Ελλάδα)' : 'Landline (Greece)';
    } else if (number.startsWith('69') ||
        number.startsWith('+3069') ||
        (number.startsWith('+30') && number.substring(3).startsWith('69'))) {
      type = isGreek ? 'Κινητό (Ελλάδα)' : 'Mobile (Greece)';
    } else if (number.startsWith('+')) {
      String? country;
      for (int len = 4; len >= 2; len--) {
        if (number.length >= len) {
          final code = number.substring(0, len);
          if (_countryCodes.containsKey(code)) { country = _countryCodes[code]; break; }
        }
      }
      type = country != null
          ? (isGreek ? 'Διεθνής — $country' : 'International — $country')
          : (isGreek ? 'Διεθνής' : 'International');
    } else if (number.startsWith('800')) {
      type = isGreek ? 'Αριθμός 800 (δωρεάν)' : 'Freephone 800';
    } else if (number.startsWith('801')) {
      type = isGreek ? 'Αριθμός 801 (αστική χρέωση)' : '801 (local rate)';
    } else if (number.startsWith('90')) {
      type = isGreek ? 'Χρεωζόμενος αριθμός 90x' : 'Premium rate 90x';
    } else {
      type = isGreek ? 'Άγνωστος τύπος' : 'Unknown type';
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(e.contactName ?? e.phoneNumber),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoRow(Icons.phone, e.phoneNumber),
            _InfoRow(Icons.category_outlined, type),
            if (origin != null)
              _InfoRow(Icons.location_on_outlined,
                  isGreek ? 'Περιοχή: $origin' : 'Area: $origin'),
            if (e.contactName != null)
              _InfoRow(Icons.person_outline, e.contactName!),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.close)),
          FilledButton.icon(
            icon: const Icon(Icons.call, size: 18),
            label: Text(s.call),
            onPressed: () { Navigator.pop(ctx); _placeCallWithCheck(e.phoneNumber); },
          ),
        ],
      ),
    );
  }

  // ── filter menu ───────────────────────────────────────────────────────────

  void _showFilterMenu(BuildContext context) {
    final s = widget.strings;
    final items = <_Filter, String>{
      _Filter.all: s.filterAll,
      _Filter.missed: s.filterMissed,
      _Filter.incoming: s.filterIncoming,
      _Filter.outgoing: s.filterOutgoing,
      _Filter.rejected: s.filterRejected,
      _Filter.international: s.filterInternational,
      _Filter.local: s.filterLocal,
    };

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  Text(s.filters,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      setLocal(() { _activeFilters..clear()..add(_Filter.all); });
                      setState(() { _activeFilters..clear()..add(_Filter.all); });
                    },
                    child: Text(s.filterAll),
                  ),
                ],
              ),
            ),
            ...items.entries.map((entry) {
              final f = entry.key;
              return CheckboxListTile(
                title: Text(entry.value),
                value: _activeFilters.contains(f),
                onChanged: (v) {
                  setLocal(() {
                    if (f == _Filter.all) {
                      _activeFilters..clear()..add(_Filter.all);
                    } else {
                      _activeFilters.remove(_Filter.all);
                      if (v == true) _activeFilters.add(f);
                      else _activeFilters.remove(f);
                      if (_activeFilters.isEmpty) _activeFilters.add(_Filter.all);
                    }
                  });
                  setState(() {});
                },
              );
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ── filter logic ──────────────────────────────────────────────────────────

  List<CallEntry> get _visible {
    var list = _entries;
    if (!_activeFilters.contains(_Filter.all)) {
      list = list.where((e) => _activeFilters.any((f) {
        switch (f) {
          case _Filter.missed:        return e.type == CallType.missed;
          case _Filter.incoming:      return e.type == CallType.incoming;
          case _Filter.outgoing:      return e.type == CallType.outgoing;
          case _Filter.rejected:      return e.type == CallType.rejected || e.type == CallType.blocked;
          case _Filter.international: return _isInternational(e.phoneNumber);
          case _Filter.local:         return !_isInternational(e.phoneNumber);
          default:                    return true;
        }
      })).toList();
    }
    if (_searchQuery.isNotEmpty) {
      list = list.where((e) {
        final name = (e.contactName ?? '').toLowerCase();
        return name.contains(_searchQuery) || e.phoneNumber.toLowerCase().contains(_searchQuery);
      }).toList();
    }
    return list;
  }

  // ── group by date ─────────────────────────────────────────────────────────

  List<Object> _grouped(List<CallEntry> entries) {
    final result = <Object>[];
    DateTime? lastDay;
    for (final e in entries) {
      final l = e.timestamp.toLocal();
      final day = DateTime(l.year, l.month, l.day);
      if (lastDay == null || day != lastDay) { result.add(day); lastDay = day; }
      result.add(e);
    }
    return result;
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  String _semanticType(CallType t) {
    switch (t) {
      case CallType.incoming: return 'incoming';
      case CallType.outgoing: return 'outgoing';
      case CallType.missed:   return 'missed';
      default:                return 'blocked';
    }
  }

  IconData _iconFor(CallType t) {
    switch (t) {
      case CallType.incoming: return Icons.call_received;
      case CallType.outgoing: return Icons.call_made;
      case CallType.missed:   return Icons.call_missed;
      case CallType.rejected:
      case CallType.blocked:  return Icons.block;
      case CallType.unknown:  return Icons.call;
    }
  }

  String _formatDuration(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  String _formatTime(DateTime dt) {
    final l = dt.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }

  static const _mEl = ['','Ιανουαρίου','Φεβρουαρίου','Μαρτίου','Απριλίου','Μαΐου',
      'Ιουνίου','Ιουλίου','Αυγούστου','Σεπτεμβρίου','Οκτωβρίου','Νοεμβρίου','Δεκεμβρίου'];
  static const _mEn = ['','January','February','March','April','May','June',
      'July','August','September','October','November','December'];

  String _formatDayHeader(DateTime day) {
    final s = widget.strings;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (day == today) return s.today;
    if (day == today.subtract(const Duration(days: 1))) return s.yesterday;
    final gr = s.lang == AppLanguage.greek;
    final m = gr ? _mEl : _mEn;
    return gr ? '${day.day} ${m[day.month]} ${day.year}' : '${m[day.month]} ${day.day}, ${day.year}';
  }

  bool get _filtersActive => !(_activeFilters.length == 1 && _activeFilters.contains(_Filter.all));

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (!_permissionGranted) return _centeredMessage(s.callLogPermissionNeeded);

    final visible = _visible;
    final grouped = _grouped(visible);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── toolbar — sits flush under the AppBar ──────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 4, 0),
          child: Row(
            children: [
              // search field (takes remaining space when open)
              if (_searchVisible)
                Expanded(
                  child: TextField(
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
                      contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                    ),
                  ),
                )
              else
                const Spacer(),

              // multi-select delete
              if (_selecting)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: s.delete,
                  onPressed: () => _deleteEntries(
                      _entries.where((e) => _selected.contains(e.id)).toList()),
                ),

              // filter with active-dot badge
              Stack(
                alignment: Alignment.topRight,
                children: [
                  IconButton(
                    icon: const Icon(Icons.filter_list),
                    tooltip: s.filters,
                    onPressed: () => _showFilterMenu(context),
                  ),
                  if (_filtersActive)
                    Positioned(
                      right: 8, top: 8,
                      child: Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),

              // search toggle
              if (!_searchVisible)
                IconButton(
                  icon: const Icon(Icons.search),
                  tooltip: s.searchCallLog,
                  onPressed: () => setState(() => _searchVisible = true),
                ),
            ],
          ),
        ),

        // ── list ──────────────────────────────────────────────────────
        Expanded(
          child: visible.isEmpty
              ? _centeredMessage(
                  _searchQuery.isNotEmpty || _filtersActive ? s.callLogNoResults : s.callLogEmpty)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: Scrollbar(
                    controller: _scrollController,
                    interactive: true,
                    thumbVisibility: true,
                    thickness: 5,
                    radius: const Radius.circular(3),
                    child: ListView.builder(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(
                          parent: ClampingScrollPhysics()),
                      padding: const EdgeInsets.only(bottom: 16),
                      addRepaintBoundaries: false,
                      addAutomaticKeepAlives: false,
                      itemCount: grouped.length,
                      itemBuilder: (context, i) {
                        final item = grouped[i];

                        if (item is DateTime) {
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                            child: Text(
                              _formatDayHeader(item),
                              style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                letterSpacing: 0.4,
                              ),
                            ),
                          );
                        }

                        final e = item as CallEntry;
                        final color = AppTheme.callTypeColor(_semanticType(e.type));
                        final isMissed = e.type == CallType.missed;
                        final isSelected = _selected.contains(e.id);

                        return Dismissible(
                          key: ValueKey(e.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            color: Colors.red,
                            child: const Icon(Icons.delete_outline, color: Colors.white),
                          ),
                          confirmDismiss: (_) async {
                            await _deleteEntries([e]);
                            return false;
                          },
                          child: GestureDetector(
                            onLongPress: () => setState(() {
                              if (isSelected) _selected.remove(e.id);
                              else _selected.add(e.id);
                            }),
                            child: Card(
                              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4)
                                  : null,
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                leading: isSelected
                                    ? CircleAvatar(
                                        radius: 22,
                                        backgroundColor: Theme.of(context).colorScheme.primary,
                                        child: const Icon(Icons.check, color: Colors.white, size: 20),
                                      )
                                    : CircleAvatar(
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
                                  '${_formatTime(e.timestamp)} · ${_formatDuration(e.duration)}'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton.filledTonal(
                                      icon: const Icon(Icons.call, size: 20),
                                      onPressed: () => _placeCallWithCheck(e.phoneNumber),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.info_outline, size: 20),
                                      tooltip: s.callInfo,
                                      onPressed: () => _showPhoneInfo(context, e),
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
          physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
          children: [
            const SizedBox(height: 120),
            Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(msg, textAlign: TextAlign.center))),
          ],
        ),
      );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow(this.icon, this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ]),
      );
}
