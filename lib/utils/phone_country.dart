/// Αναγνώριση χώρας από τον διεθνή κωδικό ενός τηλεφωνικού αριθμού,
/// και μετατροπή σε emoji σημαία.
///
/// Ελέγχουμε πρώτα τους μεγαλύτερους (3ψήφιους) κωδικούς, μετά τους
/// 2ψήφιους, μετά τους μονοψήφιους — έτσι το "30" (Ελλάδα) δεν
/// συγκρούεται λάθος με κάποιον 3ψήφιο κωδικό που ξεκινά επίσης με 30.
const Map<String, String> _callingCodeToCountry = {
  // Ευρώπη
  '30': 'GR', '31': 'NL', '32': 'BE', '33': 'FR', '34': 'ES',
  '36': 'HU', '39': 'IT', '40': 'RO', '41': 'CH', '43': 'AT',
  '44': 'GB', '45': 'DK', '46': 'SE', '47': 'NO', '48': 'PL',
  '49': 'DE', '351': 'PT', '352': 'LU', '353': 'IE', '354': 'IS',
  '356': 'MT', '357': 'CY', '358': 'FI', '359': 'BG', '370': 'LT',
  '371': 'LV', '372': 'EE', '377': 'MC', '378': 'SM', '380': 'UA',
  '385': 'HR', '386': 'SI', '420': 'CZ', '421': 'SK', '423': 'LI',
  '7': 'RU',
  // Αμερική
  '1': 'US',
  // Ασία / Ωκεανία / λοιπά
  '20': 'EG', '27': 'ZA', '61': 'AU', '64': 'NZ', '81': 'JP',
  '82': 'KR', '86': 'CN', '90': 'TR', '91': 'IN', '212': 'MA',
  '966': 'SA', '971': 'AE', '972': 'IL',
};

const Map<String, String> _countryToFlagEmoji = {
  'GR': '🇬🇷', 'NL': '🇳🇱', 'BE': '🇧🇪', 'FR': '🇫🇷', 'ES': '🇪🇸',
  'HU': '🇭🇺', 'IT': '🇮🇹', 'RO': '🇷🇴', 'CH': '🇨🇭', 'AT': '🇦🇹',
  'GB': '🇬🇧', 'DK': '🇩🇰', 'SE': '🇸🇪', 'NO': '🇳🇴', 'PL': '🇵🇱',
  'DE': '🇩🇪', 'PT': '🇵🇹', 'LU': '🇱🇺', 'IE': '🇮🇪', 'IS': '🇮🇸',
  'MT': '🇲🇹', 'CY': '🇨🇾', 'FI': '🇫🇮', 'BG': '🇧🇬', 'LT': '🇱🇹',
  'LV': '🇱🇻', 'EE': '🇪🇪', 'MC': '🇲🇨', 'SM': '🇸🇲', 'UA': '🇺🇦',
  'HR': '🇭🇷', 'SI': '🇸🇮', 'CZ': '🇨🇿', 'SK': '🇸🇰', 'LI': '🇱🇮',
  'RU': '🇷🇺', 'US': '🇺🇸', 'EG': '🇪🇬', 'ZA': '🇿🇦', 'AU': '🇦🇺',
  'NZ': '🇳🇿', 'JP': '🇯🇵', 'KR': '🇰🇷', 'CN': '🇨🇳', 'TR': '🇹🇷',
  'IN': '🇮🇳', 'MA': '🇲🇦', 'SA': '🇸🇦', 'AE': '🇦🇪', 'IL': '🇮🇱',
};

final List<String> _sortedCodesByLength = _callingCodeToCountry.keys.toList()
  ..sort((a, b) => b.length.compareTo(a.length));

/// Επιστρέφει το emoji σημαία για έναν αριθμό, ή null αν δεν
/// αναγνωρίστηκε χώρα. Περιμένει διεθνή μορφή (π.χ. "+306912345678"
/// ή "00306912345678") — για τοπικούς αριθμούς χωρίς κωδικό χώρας
/// (π.χ. "6912345678"), δεν μπορούμε να ξέρουμε τη χώρα με σιγουριά,
/// οπότε επιστρέφουμε null.
String? flagForPhoneNumber(String raw) {
  var digits = raw.replaceAll(RegExp(r'[^0-9+]'), '');

  if (digits.startsWith('00')) {
    digits = digits.substring(2);
  } else if (digits.startsWith('+')) {
    digits = digits.substring(1);
  } else {
    // Χωρίς + ή 00, δεν μπορούμε να ξεχωρίσουμε αξιόπιστα διεθνή
    // πρόθεμα από τοπικό αριθμό.
    return null;
  }

  for (final code in _sortedCodesByLength) {
    if (digits.startsWith(code)) {
      final country = _callingCodeToCountry[code]!;
      return _countryToFlagEmoji[country];
    }
  }
  return null;
}
