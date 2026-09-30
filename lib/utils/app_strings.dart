enum AppLanguage { greek, english }

class AppStrings {
  final AppLanguage lang;
  const AppStrings(this.lang);

  bool get _isGreek => lang == AppLanguage.greek;

  String get tabHistory => _isGreek ? 'Ιστορικό' : 'History';
  String get tabDialer => _isGreek ? 'Πληκτρολόγιο' : 'Dialer';
  String get tabContacts => _isGreek ? 'Επαφές' : 'Contacts';
  String get menuFakeCall => _isGreek ? 'Ψεύτικη κλήση' : 'Fake call';
  String get menuSettings => _isGreek ? 'Ρυθμίσεις' : 'Settings';
  String get menuAbout => _isGreek ? 'Σχετικά' : 'About';

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
  String get openSettings => _isGreek ? 'Άνοιγμα ρυθμίσεων' : 'Open settings';

  // ── Sync ──────────────────────────────────────────────────────────────────
  String get syncBackendProvider =>
      _isGreek ? 'Πάροχος backend' : 'Backend provider';
  String get syncDeviceIdLabel => _isGreek
      ? 'Όνομα/ID αυτής της εγκατάστασης'
      : 'Name/ID of this install';
  String get syncDeviceIdHint =>
      _isGreek ? 'π.χ. leftheris-phone' : 'e.g. leftheris-phone';
  String get syncDeviceIdHelper => _isGreek
      ? 'Ξεχωρίζει τα δικά σου δεδομένα μέσα στο database, αν το '
          'μοιράζεσαι με άλλες συσκευές/χρήστες.'
      : 'Separates your data within the database, if you share it with '
          'other devices/users.';
  String get syncEncryptionPasswordLabel => _isGreek
      ? 'Κωδικός τοπικής κρυπτογράφησης'
      : 'Local encryption password';
  String get syncEncryptionPasswordHelper => _isGreek
      ? 'Τα δεδομένα κρυπτογραφούνται στη συσκευή σου πριν ανέβουν — '
          'χωρίς αυτόν τον κωδικό δεν αποκρυπτογραφούνται.'
      : 'Your data is encrypted on your device before it\'s uploaded — '
          'without this password it can\'t be decrypted.';
  String get syncTestConnection =>
      _isGreek ? 'Δοκιμή σύνδεσης' : 'Test connection';
  String get syncNow => _isGreek ? 'Συγχρονισμός τώρα' : 'Sync now';
  String get syncConnectionOk =>
      _isGreek ? 'Σύνδεση επιτυχής' : 'Connection successful';
  String get syncSuccessPrefix => _isGreek ? 'Συγχρονισμός:' : 'Sync:';
  String get syncFailedPrefix => _isGreek ? 'Σφάλμα:' : 'Error:';
  String syncPushedCount(int n) =>
      _isGreek ? 'Εστάλησαν $n' : '$n pushed';
  String syncPulledCount(int n) =>
      _isGreek ? 'Ελήφθησαν $n' : '$n pulled';

  // ── Contacts ──────────────────────────────────────────────────────────────
  String get contactSourceTitle => _isGreek ? 'Πηγή επαφών' : 'Contact source';
  String get contactSourceEmpty => _isGreek
      ? 'Δεν βρέθηκαν πολλαπλές πηγές επαφών'
      : 'No multiple contact sources found';
  String get contactSourceEmptySubtitle => _isGreek
      ? 'Θα χρησιμοποιηθούν όλες οι επαφές της συσκευής.'
      : 'All contacts on this device will be used.';
  String get contactSourceInstructions => _isGreek
      ? 'Επίλεξε μία ή περισσότερες πηγές. Αν δεν επιλέξεις καμία, '
          'χρησιμοποιούνται όλες. Τα διπλότυπα (ίδιος αριθμός σε πάνω από '
          'μία πηγή) αφαιρούνται αυτόματα.'
      : 'Choose one or more sources. If you don\'t choose any, all of '
          'them are used. Duplicates (the same number in more than one '
          'source) are removed automatically.';
  String get contactSourceDevice =>
      _isGreek ? 'Επαφές συσκευής' : 'Device contacts';
  String get contactSourceSim => _isGreek ? 'Επαφές SIM' : 'SIM contacts';
  String get unknownContactName => _isGreek ? 'Άγνωστο' : 'Unknown';
  String get chooseNumberTitle =>
      _isGreek ? 'Επίλεξε αριθμό' : 'Choose a number';
  String get openExternalContactUnsupported => _isGreek
      ? 'Το άνοιγμα εξωτερικής επαφής δεν υποστηρίζεται σε αυτή την πλατφόρμα.'
      : 'Opening an external contact is not supported on this platform.';

  // Phone label strings
  String get phoneLabelMobile => _isGreek ? 'Κινητό' : 'Mobile';
  String get phoneLabelHome => _isGreek ? 'Σπίτι' : 'Home';
  String get phoneLabelWork => _isGreek ? 'Εργασία' : 'Work';
  String get phoneLabelMain => _isGreek ? 'Κύριο' : 'Main';
  String get phoneLabelPager => _isGreek ? 'Pager' : 'Pager';
  String get phoneLabelOther => _isGreek ? 'Άλλο' : 'Other';

  // ── Call log ──────────────────────────────────────────────────────────────
  String get callLogEmpty =>
      _isGreek ? 'Δεν έχεις καμία κλήση.' : 'You have no calls.';
  String get callLogPermissionNeeded => _isGreek
      ? 'Χρειάζεται άδεια πρόσβασης στο ιστορικό κλήσεων.'
      : 'Call log access permission is required.';
  String get today => _isGreek ? 'Σήμερα' : 'Today';
  String get yesterday => _isGreek ? 'Χθες' : 'Yesterday';

  String get searchContactsHint =>
      _isGreek ? 'Αναζήτηση επαφών...' : 'Search contacts...';
  String get contactsEmpty =>
      _isGreek ? 'Δεν έχεις καμία επαφή.' : 'You have no contacts.';
  String get contactsPermissionNeeded => _isGreek
      ? 'Χρειάζεται άδεια πρόσβασης στις επαφές.'
      : 'Contacts access permission is required.';
  String get contactsNoMatch => _isGreek
      ? 'Καμία επαφή δεν ταιριάζει με την αναζήτηση.'
      : 'No contact matches your search.';
  String get numberCopied =>
      _isGreek ? 'Ο αριθμός αντιγράφηκε' : 'Number copied';

  // ── Dialer ────────────────────────────────────────────────────────────────
  String get dialerHint =>
      _isGreek ? 'Πληκτρολόγησε αριθμό' : 'Enter a number';

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

  // ── About ──────────────────────────────────────────────────────────────────
  String get aboutTitle => _isGreek ? 'Σχετικά' : 'About';
  String get appName => _isGreek ? 'Κλήσεις' : 'Calls';
  String get version => _isGreek ? 'Έκδοση 0.1.0' : 'Version 0.1.0';
  String get aboutDescription => _isGreek
      ? 'Εφαρμογή διαχείρισης κλήσεων, με ιστορικό, πληκτρολόγιο και επαφές. Μέρος μιας σουίτας εφαρμογών με συγχρονισμό μεταξύ Android και desktop.'
      : 'A calls management app, with history, dialer, and contacts. Part of a suite of apps synced across Android and desktop.';
  String get noAnalytics => _isGreek
      ? 'Δεν συλλέγουμε στατιστικά δεδομένα χρήσης.'
      : 'We do not collect usage statistics.';
  String get orgAndContributors =>
      _isGreek ? 'Οργανισμός & Συντελεστές' : 'Organization & Contributors';
  String get orgSubtitle => _isGreek ? 'FANDCS · Ομάδα' : 'FANDCS · Team';
  String get builtWithFlutter =>
      _isGreek ? 'Χτισμένο με Flutter' : 'Built with Flutter';
  String get licenses =>
      _isGreek ? 'Άδειες χρήσης βιβλιοθηκών' : 'Open source licenses';
  String get privacyPolicy =>
      _isGreek ? 'Πολιτική Απορρήτου & Όροι Χρήσης' : 'Privacy Policy & Terms of Use';
  String get contact => _isGreek ? 'Επικοινωνία' : 'Contact';
  String get noEmailApp => _isGreek
      ? 'Δεν βρέθηκε εφαρμογή email στη συσκευή.'
      : 'No email app found on this device.';
  String couldNotOpen(String url) =>
      _isGreek ? 'Δεν ήταν δυνατό το άνοιγμα: $url' : 'Could not open: $url';

  // Updated FANDCS description
  String get orgDescription => _isGreek
      ? 'Η FANDCS είναι μια ανεξάρτητη, ανοιχτού κώδικα ομάδα ανάπτυξης που '
          'δημιουργεί ψηφιακές εμπειρίες από το 2022. Φτιάχνουμε 100% δωρεάν '
          'εφαρμογές και ιστοσελίδες με αυστηρά privacy-first φιλοσοφία: χωρίς '
          'συλλογή δεδομένων, χωρίς trackers και χωρίς διαφημίσεις. Η αποστολή '
          'μας είναι να κρατάμε τον ψηφιακό κόσμο ανοιχτό, διαφανή και '
          'προσβάσιμο σε όλους.'
      : 'FANDCS is an independent, open-source development team crafting digital '
          'experiences since 2022. We build 100% free apps and websites with a '
          'strict privacy-first approach: no data collection, no trackers, and no '
          'advertisements. Our mission is to keep the digital world open, '
          'transparent, and accessible to everyone.';

  String get githubLinkSoon =>
      _isGreek ? 'Σύνδεσμος GitHub: θα προστεθεί σύντομα.' : 'GitHub link: coming soon.';
  String get contributors => _isGreek ? 'Συντελεστές' : 'Contributors';
  String get developer => _isGreek ? 'Developer' : 'Developer';
  String get designer => 'Designer';

  // ── Fake call ──────────────────────────────────────────────────────────────
  String get fakeCallTitle => _isGreek ? 'Ψεύτικη κλήση' : 'Fake call';
  String get fakeCallDescription => _isGreek
      ? 'Ρύθμισε πώς θα φαίνεται η εισερχόμενη κλήση και πότε θα "χτυπήσει".'
      : 'Set how the incoming call will look and when it will "ring".';
  String get callerName => _isGreek ? 'Όνομα καλούντος' : 'Caller name';
  String get callerNumber =>
      _isGreek ? 'Αριθμός (εμφανίζεται μόνο)' : 'Number (display only)';
  String delaySeconds(int n) =>
      _isGreek ? 'Καθυστέρηση: $n δευτερόλεπτα' : 'Delay: $n seconds';
  String get schedule => _isGreek ? 'Προγραμματισμός' : 'Schedule';
  String get unknownCaller => _isGreek ? 'Άγνωστος αριθμός' : 'Unknown number';
  String get incomingCall => _isGreek ? 'Εισερχόμενη κλήση' : 'Incoming call';
  String get inCall => _isGreek ? 'Σε κλήση' : 'In call';
  String get decline => _isGreek ? 'Απόρριψη' : 'Decline';
  String get answer => _isGreek ? 'Απάντηση' : 'Answer';
  String get endCall => _isGreek ? 'Τερματισμός' : 'End call';
  String get cancelFakeCall =>
      _isGreek ? 'Ακύρωση ψεύτικης κλήσης' : 'Cancel fake call';
  String get fakeCallCancelled =>
      _isGreek ? 'Η ψεύτικη κλήση ακυρώθηκε.' : 'Fake call cancelled.';
  String scheduledSnackbar(int n) => _isGreek
      ? 'Η ψεύτικη κλήση θα "χτυπήσει" σε $n δευτερόλεπτα. Μπορείς να κλείσεις την εφαρμογή.'
      : 'The fake call will "ring" in $n seconds. You can close the app.';

  // Mode selector
  String get fakeCallMode =>
      _isGreek ? 'Τύπος οθόνης κλήσης' : 'Call screen type';
  String get fakeCallModeApp => _isGreek ? 'Οθόνη Callen' : 'Callen screen';
  String get fakeCallModeAppSubtitle => _isGreek
      ? 'Η δική μας οθόνη κλήσης μέσα στην εφαρμογή.'
      : 'Our own in-app call screen.';
  String get fakeCallModeSystem => _isGreek ? 'UI συσκευής' : 'Device UI';
  String get fakeCallModeSystemSubtitle => _isGreek
      ? 'Χρησιμοποιεί το προεπιλεγμένο UI κλήσης της συσκευής σου (Samsung, Xiaomi κ.λπ.).'
      : 'Uses your device\'s default call UI (Samsung, Xiaomi, etc.).';

  // System call account
  String get callAccountNotEnabled => _isGreek
      ? 'Ο λογαριασμός "Callen" δεν είναι ενεργός. Άνοιξε τις ρυθμίσεις για να τον ενεργοποιήσεις.'
      : 'The "Callen" calling account is not enabled. Open settings to activate it.';
  String get callAccountSettingsOpened => _isGreek
      ? 'Άνοιξαν οι ρυθμίσεις λογαριασμών κλήσης — ενεργοποίησε το "Callen".'
      : 'Call account settings opened — enable "Callen" there.';

  // Close-app hint
  String get fakeCallCloseAppHint => _isGreek
      ? 'Μπορείς να κλείσεις ή να βγεις από την εφαρμογή αφού πατήσεις «Προγραμματισμός». Η κλήση θα χτυπήσει κανονικά.'
      : 'You can close or leave the app after tapping Schedule. The call will still ring.';

  // In-call labels
  String get keypadLabel => _isGreek ? 'Πλήκτρα' : 'Keypad';
  String get muteLabel => _isGreek ? 'Σίγαση' : 'Mute';
  String get speakerLabel => _isGreek ? 'Ηχείο' : 'Speaker';
  String get holdLabel => _isGreek ? 'Αναμονή' : 'Hold';
  String get hideKeypad => _isGreek ? 'Απόκρυψη πληκτρολογίου' : 'Hide keypad';

  // ── Call log extras ────────────────────────────────────────────────────────
  String get searchCallLog => _isGreek ? 'Αναζήτηση κλήσεων...' : 'Search calls...';
  String get filterAll => _isGreek ? 'Όλες' : 'All';
  String get filterMissed => _isGreek ? 'Αναπάντητες' : 'Missed';
  String get callLogNoResults => _isGreek
      ? 'Δεν βρέθηκαν κλήσεις.'
      : 'No calls found.';
  String get filterIncoming => _isGreek ? 'Εισερχόμενες' : 'Incoming';
  String get filterOutgoing => _isGreek ? 'Εξερχόμενες' : 'Outgoing';
  String get filterRejected => _isGreek ? 'Απορριφθείσες' : 'Rejected';
}
