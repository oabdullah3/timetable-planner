/// Derives a short abbreviation from a course name, e.g.
/// "Chinese Civilisation - History and Philosophy" -> "CCHP".
///
/// Rules:
/// - split the name into tokens on any non-alphanumeric character,
/// - keep only tokens that start with a letter,
/// - drop common connector words (case-insensitive),
/// - take the uppercase first letter of each remaining token,
/// - cap at [maxLength] letters.
///
/// Returns [fallback] when nothing can be derived (e.g. an empty name).
String courseAbbreviation(String name, {String fallback = '', int maxLength = 6}) {
  if (name.trim().isEmpty) return fallback;

  const connectors = {
    'and', 'or', 'of', 'the', 'a', 'an', 'in', 'on', 'at',
    'for', 'to', 'with', 'by', 'from',
  };

  final tokens = name
      .split(RegExp(r'[^A-Za-z0-9]+'))
      .where((t) => t.isNotEmpty)
      .toList();

  final letters = <String>[];
  for (final token in tokens) {
    if (!RegExp(r'^[A-Za-z]').hasMatch(token)) continue; // must start with a letter
    if (connectors.contains(token.toLowerCase())) continue;
    letters.add(token[0].toUpperCase());
    if (letters.length >= maxLength) break;
  }

  return letters.isEmpty ? fallback : letters.join();
}
