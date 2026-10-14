/// Search-only folding for Spanish, Galician and French place names.
/// Display names and stored data retain their original spelling.
String foldPlaceName(String value) {
  const groups = {
    'a': 'àáâãäåāăą',
    'c': 'çćĉċč',
    'd': 'ďđ',
    'e': 'èéêëēĕėęě',
    'g': 'ĝğġģ',
    'i': 'ìíîïĩīĭįı',
    'l': 'ĺļľł',
    'n': 'ñńņň',
    'o': 'òóôõöøōŏő',
    'r': 'ŕŗř',
    's': 'śŝşš',
    't': 'ţťŧ',
    'u': 'ùúûüũūŭůűų',
    'y': 'ýÿŷ',
    'z': 'źżž',
  };
  var result = value.toLowerCase();
  for (final entry in groups.entries) {
    for (final letter in entry.value.split('')) {
      result = result.replaceAll(letter, entry.key);
    }
  }
  return result
      .replaceAll('œ', 'oe')
      .replaceAll('æ', 'ae')
      .replaceAll(RegExp(r'[\u0300-\u036f]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

bool matchesPlaceName(String name, String query) =>
    foldPlaceName(name).contains(foldPlaceName(query));
