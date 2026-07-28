import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'services/calls_service.dart';
import 'services/calls_service_android.dart';
import 'services/calls_service_stub.dart';
import 'services/contacts_service.dart';
import 'services/contacts_service_android.dart';
import 'services/contacts_service_stub.dart';
import 'services/settings_store.dart';
import 'screens/dialer_screen.dart';
import 'screens/call_log_screen.dart';
import 'screens/contacts_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/about_screen.dart';
import 'screens/fake_call_setup_screen.dart';
import 'screens/fake_call_screen.dart';
import 'theme/app_theme.dart';
import 'utils/app_strings.dart';

const _fakeCallChannel = MethodChannel('gr.fandcs.callen/fakecall');
final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  // Χρειάζεται πριν από οποιοδήποτε await στο main() όταν θα τρέξει
  // πλατφόρμα-εξαρτώμενος κώδικας (εδώ: SharedPreferences) πριν το
  // runApp.
  WidgetsFlutterBinding.ensureInitialized();
  final store = await SettingsStore.load();
  runApp(AppCallsRoot(store: store));
}

ThemeMode _themeModeFromString(String value) {
  switch (value) {
    case 'light':
      return ThemeMode.light;
    case 'dark':
      return ThemeMode.dark;
    default:
      return ThemeMode.system;
  }
}

/// Αν η προτίμηση είναι 'system', κοιτάμε τη γλώσσα συσκευής: αν είναι
/// Ελληνικά χρησιμοποιούμε Ελληνικά, αλλιώς Αγγλικά (default). Αν ο
/// χρήστης έχει διαλέξει ρητά 'el' ή 'en', το σεβόμαστε ανεξάρτητα από
/// το σύστημα.
AppLanguage _resolveLanguage(String stored, Locale systemLocale) {
  switch (stored) {
    case 'el':
      return AppLanguage.greek;
    case 'en':
      return AppLanguage.english;
    default:
      return systemLocale.languageCode == 'el'
          ? AppLanguage.greek
          : AppLanguage.english;
  }
}

class AppCallsRoot extends StatefulWidget {
  final SettingsStore store;
  const AppCallsRoot({super.key, required this.store});

  @override
  State<AppCallsRoot> createState() => _AppCallsRootState();
}

class _AppCallsRootState extends State<AppCallsRoot> {
  late ThemeMode _themeMode = _themeModeFromString(widget.store.themeMode);
  late String _languagePref = widget.store.language; // 'system' | 'el' | 'en'

  @override
  void initState() {
    super.initState();
    // Ακούει πότε το native side (AlarmManager) ξαναφέρνει την
    // εφαρμογή μπροστά με μια "χτυπημένη" ψεύτικη κλήση.
    _fakeCallChannel.setMethodCallHandler((call) async {
      if (call.method == 'onFakeCallTriggered') {
        final args = Map<String, dynamic>.from(call.arguments as Map);
        _showFakeCallScreen(args['name'] as String, args['number'] as String);
      }
    });
    // Έλεγχος αν η εφαρμογή μόλις άνοιξε ΕΞΑΙΤΙΑΣ μιας ψεύτικης
    // κλήσης (cold start από το alarm), όχι μόνο resume από background.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final pending = await _fakeCallChannel.invokeMethod('consumePending');
      if (pending != null) {
        final args = Map<String, dynamic>.from(pending as Map);
        _showFakeCallScreen(args['name'] as String, args['number'] as String);
      }
    });
  }

  void _showFakeCallScreen(String name, String number) {
    final language = _resolveLanguage(
      _languagePref,
      WidgetsBinding.instance.platformDispatcher.locale,
    );
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => FakeCallScreen(
          callerName: name,
          callerNumber: number,
          strings: AppStrings(language),
        ),
        fullscreenDialog: true,
      ),
    );
  }

  void _setThemeMode(ThemeMode mode) {
    setState(() => _themeMode = mode);
    widget.store.setThemeMode(mode.name);
  }

  void _setLanguagePref(String pref) {
    setState(() => _languagePref = pref);
    widget.store.setLanguage(pref);
  }

  @override
  Widget build(BuildContext context) {
    final systemLocale = WidgetsBinding.instance.platformDispatcher.locale;
    final language = _resolveLanguage(_languagePref, systemLocale);
    final strings = AppStrings(language);

    // Επιλογή πραγματικής ή stub υλοποίησης ανάλογα με την πλατφόρμα.
    // Android -> πραγματικό telephony access.
    // Linux/Windows -> stub (δεν υπάρχει GSM hardware).
    final CallsService callsService = Platform.isAndroid
        ? CallsServiceAndroid(deviceId: 'device-placeholder')
        : CallsServiceStub();

    final ContactsService contactsService =
        Platform.isAndroid ? ContactsServiceAndroid() : ContactsServiceStub();

    return MaterialApp(
      title: 'Κλήσεις',
      navigatorKey: navigatorKey,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _themeMode,
      // Αυτό μεταφράζει αυτόματα τα ενσωματωμένα Material strings του
      // Flutter (π.χ. "Show menu" -> "Εμφάνιση μενού", "Paste" ->
      // "Επικόλληση", "Copy" -> "Αντιγραφή") — δεν τα γράφουμε εμείς,
      // τα παρέχει ήδη το Flutter SDK για την ελληνική γλώσσα.
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('el'), Locale('en')],
      locale: Locale(language == AppLanguage.greek ? 'el' : 'en'),
      home: HomeShell(
        callsService: callsService,
        contactsService: contactsService,
        themeMode: _themeMode,
        onThemeModeChanged: _setThemeMode,
        store: widget.store,
        strings: strings,
        languagePref: _languagePref,
        onLanguageChanged: _setLanguagePref,
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  final CallsService callsService;
  final ContactsService contactsService;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final SettingsStore store;
  final AppStrings strings;
  final String languagePref;
  final ValueChanged<String> onLanguageChanged;

  const HomeShell({
    super.key,
    required this.callsService,
    required this.contactsService,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.store,
    required this.strings,
    required this.languagePref,
    required this.onLanguageChanged,
  });

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  // Ξεκινάει από το Πληκτρολόγιο (index 1), όχι το Ιστορικό.
  int _index = 1;
  int _previousIndex = 1;

  void _onTabSelected(int newIndex) {
    if (newIndex == _index) return;
    setState(() {
      _previousIndex = _index;
      _index = newIndex;
    });
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          themeMode: widget.themeMode,
          onThemeModeChanged: widget.onThemeModeChanged,
          store: widget.store,
          strings: widget.strings,
          languagePref: widget.languagePref,
          onLanguageChanged: widget.onLanguageChanged,
          contactsService: widget.contactsService,
        ),
      ),
    );
  }

  void _openAbout() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AboutScreen(strings: widget.strings)),
    );
  }

  void _openFakeCall() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FakeCallSetupScreen(strings: widget.strings),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    final screens = [
      CallLogScreen(
        callsService: widget.callsService,
        contactsService: widget.contactsService,
        strings: s,
        store: widget.store,
      ),
      DialerScreen(callsService: widget.callsService, strings: s),
      ContactsScreen(
        contactsService: widget.contactsService,
        callsService: widget.callsService,
        strings: s,
        store: widget.store,
      ),
    ];

    final titles = [s.tabHistory, s.tabDialer, s.tabContacts];

    // Κατεύθυνση μετάβασης: πάμε δεξιά αν το νέο tab είναι μετά το
    // προηγούμενο στη σειρά, αλλιώς αριστερά.
    final movingForward = _index >= _previousIndex;

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_index]),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'settings') _openSettings();
              if (value == 'about') _openAbout();
              if (value == 'fake_call') _openFakeCall();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'fake_call',
                child: ListTile(
                  leading: const Icon(Icons.phone_callback_outlined),
                  title: Text(s.menuFakeCall),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'settings',
                child: ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: Text(s.menuSettings),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'about',
                child: ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text(s.menuAbout),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          final offsetAnimation = Tween<Offset>(
            begin: Offset(movingForward ? 0.06 : -0.06, 0),
            end: Offset.zero,
          ).animate(animation);
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: offsetAnimation, child: child),
          );
        },
        child: KeyedSubtree(
          key: ValueKey<int>(_index),
          child: screens[_index],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _onTabSelected,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.history_outlined),
            selectedIcon: const Icon(Icons.history),
            label: s.tabHistory,
          ),
          NavigationDestination(
            icon: const Icon(Icons.dialpad_outlined),
            selectedIcon: const Icon(Icons.dialpad),
            label: s.tabDialer,
          ),
          NavigationDestination(
            icon: const Icon(Icons.contacts_outlined),
            selectedIcon: const Icon(Icons.contacts),
            label: s.tabContacts,
          ),
        ],
      ),
    );
  }
}
