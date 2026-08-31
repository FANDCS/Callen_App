





const Map<String, String> _callingCodeToCountry = {
  
  '30': 'GR', '31': 'NL', '32': 'BE', '33': 'FR', '34': 'ES',
  '36': 'HU', '39': 'IT', '40': 'RO', '41': 'CH', '43': 'AT',
  '44': 'GB', '45': 'DK', '46': 'SE', '47': 'NO', '48': 'PL',
  '49': 'DE', '351': 'PT', '352': 'LU', '353': 'IE', '354': 'IS',
  '356': 'MT', '357': 'CY', '358': 'FI', '359': 'BG', '370': 'LT',
  '371': 'LV', '372': 'EE', '377': 'MC', '378': 'SM', '380': 'UA',
  '385': 'HR', '386': 'SI', '420': 'CZ', '421': 'SK', '423': 'LI',
  '7': 'RU',
  
  '1': 'US',
  
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






String? flagForPhoneNumber(String raw) {
  var digits = raw.replaceAll(RegExp(r'[^0-9+]'), '');

  if (digits.startsWith('00')) {
    digits = digits.substring(2);
  } else if (digits.startsWith('+')) {
    digits = digits.substring(1);
  } else {
    
    
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
