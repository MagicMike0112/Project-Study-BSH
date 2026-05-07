class AppTime {
  const AppTime._();

  /// Parse server timestamp into local wall-clock time consistently.
  ///
  /// We intentionally preserve wall-clock components to avoid double
  /// timezone shifting when data sources contain mixed timezone semantics.
  static DateTime? parseServerTimestamp(dynamic value) {
    if (value == null) return null;
    final raw = value.toString().trim();
    if (raw.isEmpty) return null;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return null;

    // If timestamp explicitly carries timezone info (e.g. trailing "Z"
    // or "+08:00"), convert to local time for UI.
    final hasTimezone = RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(raw);
    if (hasTimezone) {
      return parsed.toLocal();
    }

    // No timezone in payload: treat as local wall-clock to avoid shifting.
    return parsed;
  }

  static String toUtcIso(DateTime value) => value.toUtc().toIso8601String();
}
