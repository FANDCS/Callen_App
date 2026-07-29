/// Ελαφρύ, χειροκίνητο σύστημα μεταφράσεων (χωρίς flutter_localizations
/// gen-l10n, για να μη μπλέξουμε με επιπλέον build step). Καλύπτει το
/// σύνολο του ορατού κειμένου της εφαρμογής. Τα ενσωματωμένα Material
/// strings (π.χ. "Show menu", "Paste", "Copy") μεταφράζονται ξεχωριστά,
/// αυτόματα, μέσω του flutter_localizations στο main.dart.
enum AppLanguage { greek, english }

class AppStrings {
  final AppLanguage lang;
  const AppStrings(this.lang);

  bool get _isGreek => lang == AppLanguage.greek;

  // --- Πλοήγηση / Μενού ---
  String get tabHistory => _isGreek ? 'Ιστορικό' : 'History';
  String get tabDialer => _isGreek ? 'Πληκτρολόγιο' : 'Dialer';
  String get tabContacts => _isGreek ? 'Επαφές' : 'Contacts';
  String get menuFakeCall => _isGreek ? 'Ψεύτικη κλήση' : 'Fake call';
  String get menuSettings => _isGreek ? 'Ρυθμίσεις' : 'Settings';
  String get menuAbout => _isGreek ? 'Σχετικά' : 'About';

  // --- Ρυθμίσεις ---
  String get settingsTitle => _isGreek ? 'Ρυθμίσεις' : 'Settings';
  String get settingsAppearance => _isGreek ? 'Εμφάνιση' : 'Appearance';
  String get settingsLanguage => _isGreek ? 'Γλώσσα' : 'Language';
  String get langSystem => _isGreek ? 'Ίδιο με το σύστημα' : 'System default';
  String get langGreek => 'Ελληνικά';
  String get langEnglish => 'English';
  String get themeLight => _isGreek ? 'Φωτεινό' : 'Light';
  String get themeDark => _isGreek ? 'Σκοτεινό' : 'Dark';
  String get settingsSync =>
      _isGreek ? 'Συγχρονισμός (χειροκίνητη ρύθμιση)' : 'Sync (manual setup)';
  String get syncEnable => _isGreek ? 'Ενεργοποίηση συγχρονισμού' : 'Enable sync';
  String get syncEnableSubtitle => _isGreek
      ? 'Το sync engine δεν είναι έτοιμο ακόμα — απλά αποθηκεύει τις ρυθμίσεις για αργότερα'
      : 'The sync engine isn\'t ready yet — this just saves the settings for later';
  String get syncServerUrl => _isGreek ? 'Διεύθυνση server (URL)' : 'Server URL';
  String get syncApiKey => _isGreek ? 'API Key / Token' : 'API Key / Token';
  String get save => _isGreek ? 'Αποθήκευση' : 'Save';
  String get saved => _isGreek ? 'Αποθηκεύτηκε' : 'Saved';
  String get settingsSaved =>
      _isGreek ? 'Οι ρυθμίσεις αποθηκεύτηκαν' : 'Settings saved';

  String get callLogEmpty => _isGreek ? 'Δεν έχεις καμία κλήση.' : 'You have no calls.';
  String get callLogPermissionNeeded => _isGreek
      ? 'Χρειάζεται άδεια πρόσβασης στο ιστορικό κλήσεων.'
      : 'Call log access permission is required.';
  String get today => _isGreek ? 'Σήμερα' : 'Today';
  String get yesterday => _isGreek ? 'Χθες' : 'Yesterday';

  String get searchContactsHint =>
      _isGreek ? 'Αναζήτηση επαφών...' : 'Search contacts...';
  String get contactsEmpty => _isGreek ? 'Δεν έχεις καμία επαφή.' : 'You have no contacts.';
  String get contactsPermissionNeeded => _isGreek
      ? 'Χρειάζεται άδεια πρόσβασης στις επαφές.'
      : 'Contacts access permission is required.';
  String get contactsNoMatch => _isGreek
      ? 'Καμία επαφή δεν ταιριάζει με την αναζήτηση.'
      : 'No contact matches your search.';
  String get numberCopied => _isGreek ? 'Ο αριθμός αντιγράφηκε' : 'Number copied';

  // --- Πληκτρολόγιο ---
  String get dialerHint =>
      _isGreek ? 'Πληκτρολόγησε αριθμό' : 'Enter a number';

  /// Γράμματα κάτω από κάθε ψηφίο στο πληκτρολόγιο — ελληνικό ή
  /// αγγλικό keypad layout ανάλογα με τη γλώσσα.
  Map<String, String> get keypadLetters => _isGreek
      ? const {
          '1': '', '2': 'ΑΒΓ', '3': 'ΔΕΖ',
          '4': 'ΗΘΙ', '5': 'ΚΛΜ', '6': 'ΝΞΟ',
          '7': 'ΠΡΣ', '8': 'ΤΥΦ', '9': 'ΧΨΩ',
          '0': '+', '*': '', '#': '',
        }
      : const {
          '1': '', '2': 'ABC', '3': 'DEF',
          '4': 'GHI', '5': 'JKL', '6': 'MNO',
          '7': 'PQRS', '8': 'TUV', '9': 'WXYZ',
          '0': '+', '*': '', '#': '',
        };

  // --- Σχετικά ---
  String get aboutTitle => _isGreek ? 'Σχετικά' : 'About';
  String get appName => _isGreek ? 'Κλήσεις' : 'Calls';
  String get version => _isGreek ? 'Έκδοση 0.1.0' : 'Version 0.1.0';
  String get aboutDescription => _isGreek
      ? 'Εφαρμογή διαχείρισης κλήσεων, με ιστορικό, πληκτρολόγιο και επαφές. Μέρος μιας σουίτας εφαρμογών με συγχρονισμό μεταξύ Android και desktop.'
      : 'A calls management app, with history, dialer, and contacts. Part of a suite of apps synced across Android and desktop.';
  String get orgAndContributors =>
      _isGreek ? 'Οργανισμός & Συντελεστές' : 'Organization & Contributors';
  String get orgSubtitle => _isGreek ? 'FANDCS · Ομάδα' : 'FANDCS · Team';
  String get builtWithFlutter =>
      _isGreek ? 'Χτισμένο με Flutter' : 'Built with Flutter';
  String get licenses => _isGreek ? 'Άδειες χρήσης βιβλιοθηκών' : 'Open source licenses';
  String get privacyPolicy =>
      _isGreek ? 'Πολιτική Απορρήτου & Όροι Χρήσης' : 'Privacy Policy & Terms of Use';
  String get contact => _isGreek ? 'Επικοινωνία' : 'Contact';
  String get noEmailApp => _isGreek
      ? 'Δεν βρέθηκε εφαρμογή email στη συσκευή.'
      : 'No email app found on this device.';
  String couldNotOpen(String url) =>
      _isGreek ? 'Δεν ήταν δυνατό το άνοιγμα: $url' : 'Could not open: $url';

  // --- Οργανισμός ---
  String get orgDescription => _isGreek
      ? 'Ο οργανισμός/ομάδα πίσω από την ανάπτυξη και τον σχεδιασμό αυτής της εφαρμογής και της υπόλοιπης σουίτας εφαρμογών.'
      : 'The organization/team behind the development and design of this app and the rest of the app suite.';
  String get githubLinkSoon =>
      _isGreek ? 'Σύνδεσμος GitHub: θα προστεθεί σύντομα.' : 'GitHub link: coming soon.';
  String get contributors => _isGreek ? 'Συντελεστές' : 'Contributors';
  String get developer => _isGreek ? 'Developer' : 'Developer';
  String get designer => _isGreek ? 'Designer (θέση διαθέσιμη)' : 'Designer (position open)';

  // --- Ψεύτικη κλήση ---
  String get fakeCallTitle => _isGreek ? 'Ψεύτικη κλήση' : 'Fake call';
  String get fakeCallDescription => _isGreek
      ? 'Ρύθμισε πώς θα φαίνεται η εισερχόμενη κλήση και πότε θα "χτυπήσει".'
      : 'Set how the incoming call will look and when it will "ring".';
  String get callerName => _isGreek ? 'Όνομα καλούντος' : 'Caller name';
  String get callerNumber =>
      _isGreek ? 'Αριθμός (εμφανίζεται μόνο)' : 'Number (display only)';
  String delaySeconds(int n) =>
      _isGreek ? 'Καθυστέρηση: $n δευτερόλεπτα' : 'Delay: $n seconds';
  String scheduledSnackbar(int n) => _isGreek
      ? 'Η ψεύτικη κλήση θα "χτυπήσει" σε $n δευτερόλεπτα — κράτα την εφαρμογή ανοιχτή.'
      : 'The fake call will "ring" in $n seconds — keep the app open.';
  String get schedule => _isGreek ? 'Προγραμματισμός' : 'Schedule';
  String get unknownCaller => _isGreek ? 'Άγνωστος αριθμός' : 'Unknown number';
  String get incomingCall => _isGreek ? 'Εισερχόμενη κλήση' : 'Incoming call';
  String get inCall => _isGreek ? 'Σε κλήση' : 'In call';
  String get decline => _isGreek ? 'Απόρριψη' : 'Decline';
  String get answer => _isGreek ? 'Απάντηση' : 'Answer';
  String get endCall => _isGreek ? 'Τερματισμός' : 'End call';
}
