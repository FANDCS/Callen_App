import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/call_entry.dart';
import '../services/calls_service.dart';
import '../services/contacts_service.dart';
import '../services/settings_store.dart';
import '../theme/app_theme.dart';
import '../utils/app_strings.dart';
import '../utils/phone_utils.dart';

// ── Area code lookup ──────────────────────────────────────────────────────────

Map<String, String>? _grCodes;

Future<Map<String, String>> _loadGrCodes() async {
  if (_grCodes != null) return _grCodes!;
  try {
    final raw = await rootBundle.loadString('assets/data/gr_area_codes.json');
    _grCodes = Map<String, String>.from(json.decode(raw) as Map);
  } catch (_) {
    _grCodes = {};
  }
  return _grCodes!;
}

// Fallback when the exact code is not in the table: region of the zone (2nd digit).
const _grZones = {
  '21': 'Αθήνα – Πειραιάς',
  '22': 'Στερεά Ελλάδα / Αττική / Νησιά Αιγαίου',
  '23': 'Κεντρική Μακεδονία',
  '24': 'Θεσσαλία / Δυτική Μακεδονία',
  '25': 'Ανατολική Μακεδονία & Θράκη',
  '26': 'Ήπειρος / Δυτική Ελλάδα / Ιόνια Νησιά',
  '27': 'Πελοπόννησος',
  '28': 'Κρήτη',
};

String? _lookupCity(String localNumber, Map<String, String> codes) {
  for (int len = 5; len >= 3; len--) {
    if (localNumber.length >= len) {
      final key = localNumber.substring(0, len);
      if (codes.containsKey(key)) return codes[key];
    }
  }
  if (localNumber.length >= 2) return _grZones[localNumber.substring(0, 2)];
  return null;
}

// ── Country code lookup ───────────────────────────────────────────────────────

const _countryCodes = {
  '+1': 'USA/Canada', '+7': 'Russia', '+20': 'Egypt',
  '+27': 'South Africa', '+30': 'Greece', '+31': 'Netherlands',
  '+32': 'Belgium', '+33': 'France', '+34': 'Spain',
  '+36': 'Hungary', '+39': 'Italy', '+40': 'Romania',
  '+41': 'Switzerland', '+43': 'Austria', '+44': 'UK',
  '+45': 'Denmark', '+46': 'Sweden', '+47': 'Norway',
  '+48': 'Poland', '+49': 'Germany', '+52': 'Mexico',
  '+54': 'Argentina', '+55': 'Brazil', '+56': 'Chile',
  '+57': 'Colombia', '+60': 'Malaysia', '+61': 'Australia',
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

String? _lookupCountry(String number) {
  for (int len = 4; len >= 2; len--) {
    if (number.length >= len) {
      final code = number.substring(0, len);
      if (_countryCodes.containsKey(code)) return _countryCodes[code];
    }
  }
  return null;
}

// ── Filter enum ───────────────────────────────────────────────────────────────

enum _Filter { all, missed, incoming, outgoing, rejected, international, local }

// ── Widget ────────────────────────────────────────────────────────────────────

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
  Map<String, String> _grAreaCodes = {};

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
    _searchController.addListener(
        () => setState(() => _searchQuery = _searchController.text.trim().toLowerCase()));
    _init();
  }

  Future<void> _init() async {
    // Area codes load in parallel; they are only needed when the info dialog opens.
    _loadGrCodes().then((codes) => _grAreaCodes = codes);
    await _load();
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
        sourceIds: widget.store.contactSources);
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
          await MethodChannel('gr.fandcs.callen/calllog').invokeMethod('deleteEntry', {
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
    setState(() { _entries.removeWhere((e) => ids.contains(e.id)); _selected.clear(); });
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(s.callDeleted)));
  }

  // ── call with confirm ─────────────────────────────────────────────────────

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
    var number = e.phoneNumber.replaceAll(RegExp(r'[\s\-()]'), '');
    if (number.startsWith('0030')) number = '+30${number.substring(4)}';
    String? origin;
    String type;

    if (number.startsWith('+30') ||
        (!number.startsWith('+') && (number.startsWith('2') || number.startsWith('69')))) {
      final local = number.startsWith('+30') ? number.substring(3) : number;
      if (local.startsWith('69') || local.startsWith('6')) {
        type = isGreek ? 'Κινητό (Ελλάδα)' : 'Mobile (Greece)';
      } else {
        origin = _lookupCity(local, _grAreaCodes);
        type = isGreek ? 'Σταθερό (Ελλάδα)' : 'Landline (Greece)';
      }
    } else if (number.startsWith('+')) {
      final country = _lookupCountry(number);
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

  // ── filter dialog (scrollable) ────────────────────────────────────────────

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

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Row(
            children: [
              Expanded(child: Text(s.filters,
                  style: const TextStyle(fontWeight: FontWeight.w700))),
              TextButton(
                child: Text(s.filterAll),
                onPressed: () {
                  setLocal(() { _activeFilters..clear()..add(_Filter.all); });
                  setState(() { _activeFilters..clear()..add(_Filter.all); });
                },
              ),
            ],
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: items.entries.map((entry) {
                final f = entry.key;
                return CheckboxListTile(
                  dense: true,
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
              }).toList(),
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(s.close),
            ),
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
        return name.contains(_searchQuery) ||
            e.phoneNumber.toLowerCase().contains(_searchQuery);
      }).toList();
    }
    return list;
  }

  // ── grouping ──────────────────────────────────────────────────────────────

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

  String _fmt(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  String _fmtTime(DateTime dt) {
    final l = dt.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }

  static const _mEl = ['','Ιανουαρίου','Φεβρουαρίου','Μαρτίου','Απριλίου','Μαΐου',
      'Ιουνίου','Ιουλίου','Αυγούστου','Σεπτεμβρίου','Οκτωβρίου','Νοεμβρίου','Δεκεμβρίου'];
  static const _mEn = ['','January','February','March','April','May','June',
      'July','August','September','October','November','December'];

  String _dayHeader(DateTime day) {
    final s = widget.strings;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (day == today) return s.today;
    if (day == today.subtract(const Duration(days: 1))) return s.yesterday;
    final gr = s.lang == AppLanguage.greek;
    final m = gr ? _mEl : _mEn;
    return gr ? '${day.day} ${m[day.month]} ${day.year}' : '${m[day.month]} ${day.day}, ${day.year}';
  }

  bool get _filtersActive =>
      !(_activeFilters.length == 1 && _activeFilters.contains(_Filter.all));

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (!_permissionGranted) return _msg(s.callLogPermissionNeeded);

    final visible = _visible;
    final grouped = _grouped(visible);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── toolbar ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 4, 0),
          child: Row(
            children: [
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
              if (_selecting)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: s.delete,
                  onPressed: () => _deleteEntries(
                      _entries.where((e) => _selected.contains(e.id)).toList()),
                ),
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
              if (!_searchVisible)
                IconButton(
                  icon: const Icon(Icons.search),
                  tooltip: s.searchCallLog,
                  onPressed: () => setState(() => _searchVisible = true),
                ),
            ],
          ),
        ),

        // ── list ──────────────────────────────────────────────────────────
        Expanded(
          child: visible.isEmpty
              ? _msg(_searchQuery.isNotEmpty || _filtersActive
                  ? s.callLogNoResults : s.callLogEmpty)
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
                      // Repaint boundaries stay ON: each row (Card + shadow) is
                      // cached as its own layer instead of being repainted on
                      // every scroll frame.
                      addAutomaticKeepAlives: false,
                      itemCount: grouped.length,
                      itemBuilder: (context, i) {
                        final item = grouped[i];
                        if (item is DateTime) {
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                            child: Text(_dayHeader(item),
                                style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w700,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  letterSpacing: 0.4,
                                )),
                          );
                        }
                        final e = item as CallEntry;
                        final color = AppTheme.callTypeColor(_semanticType(e.type));
                        final isMissed = e.type == CallType.missed;
                        final isSel = _selected.contains(e.id);

                        return Dismissible(
                          key: ValueKey(e.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            color: Colors.red,
                            child: const Icon(Icons.delete_outline, color: Colors.white),
                          ),
                          confirmDismiss: (_) async { await _deleteEntries([e]); return false; },
                          child: GestureDetector(
                            onLongPress: () => setState(() {
                              if (isSel) _selected.remove(e.id);
                              else _selected.add(e.id);
                            }),
                            child: Card(
                              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              color: isSel
                                  ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4)
                                  : null,
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                leading: isSel
                                    ? CircleAvatar(
                                        radius: 22,
                                        backgroundColor: Theme.of(context).colorScheme.primary,
                                        child: const Icon(Icons.check, color: Colors.white, size: 20))
                                    : CircleAvatar(
                                        radius: 22,
                                        backgroundColor: color.withValues(alpha: 0.14),
                                        child: Icon(_iconFor(e.type), color: color, size: 22)),
                                title: Text(e.contactName ?? e.phoneNumber,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: isMissed ? AppColors.missed : null,
                                    )),
                                subtitle: Text('${_fmtTime(e.timestamp)} · ${_fmt(e.duration)}'),
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

  Widget _msg(String msg) => RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
          children: [
            const SizedBox(height: 120),
            Center(child: Padding(padding: const EdgeInsets.all(24),
                child: Text(msg, textAlign: TextAlign.center))),
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
