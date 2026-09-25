import 'package:intl/intl.dart';

import '../../data/models/catalog_models.dart';

final _num = NumberFormat('#,###', 'en');

/// 750000 → "750,000 د.ع". Western digits, as used in the providers' own
/// catalogs.
String formatIqd(double value, {String currency = 'IQD'}) {
  final n = _num.format(value.round());
  return currency == 'USD' ? '\$$n' : '$n د.ع';
}

String formatRange(double? from, double? to, {String currency = 'IQD'}) {
  if (from == null && to == null) return 'السعر غير متوفر';
  if (from != null && to != null && to != from) {
    return '${_num.format(from.round())} – ${formatIqd(to, currency: currency)}';
  }
  return formatIqd((from ?? to)!, currency: currency);
}

/// Card / header price label. Offers are always labelled as offers.
String displayPriceLabel(DisplayPrice p) {
  final range = formatRange(p.from, p.to);
  return p.isOffer ? 'عروض من ${formatIqd(p.from)}' : (p.to == null ? 'من $range' : range);
}

String formatDate(DateTime d) => DateFormat('yyyy/MM/dd', 'en').format(d.toLocal());

/// Normalises Arabic-Indic digits and strips spaces — the server does the
/// same, this only keeps client-side validation consistent with it.
String normalizePhone(String input) {
  const ar = '٠١٢٣٤٥٦٧٨٩';
  const fa = '۰۱۲۳۴۵۶۷۸۹';
  final b = StringBuffer();
  for (final ch in input.trim().split('')) {
    final i = ar.indexOf(ch);
    final j = fa.indexOf(ch);
    b.write(i >= 0 ? '$i' : (j >= 0 ? '$j' : ch));
  }
  return b.toString();
}

/// Mirrors the server rule: 7–15 digits, only digits/+/()/space/dash.
bool isValidPhone(String input) {
  final v = normalizePhone(input);
  if (!RegExp(r'^[0-9+() -]{7,25}$').hasMatch(v)) return false;
  final digits = v.replaceAll(RegExp(r'\D'), '');
  return digits.length >= 7 && digits.length <= 15;
}
