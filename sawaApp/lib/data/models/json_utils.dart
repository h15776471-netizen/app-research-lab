/// Small, strict helpers for reading Supabase / catalog rows.
///
/// Rows come from two places with the same shape — the Supabase REST API and
/// the bundled `assets/data/catalog.json` — so every model parses both.
library;

String? str(Object? v) {
  if (v is! String) return null;
  final t = v.trim();
  return t.isEmpty ? null : t;
}

String reqStr(Map<String, dynamic> j, String key) {
  final v = str(j[key]);
  if (v == null) throw FormatException('Missing required "$key"');
  return v;
}

/// Postgres `numeric` arrives as a number from JSON and sometimes as a
/// string from PostgREST — accept both.
double? numOrNull(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

int? intOrNull(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

DateTime? dateOrNull(Object? v) => v is String && v.isNotEmpty ? DateTime.tryParse(v) : null;

List<Map<String, dynamic>> rows(Object? v) =>
    v is List ? v.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList() : const [];
