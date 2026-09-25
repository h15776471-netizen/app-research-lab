import '../../../../core/utils/formatters.dart';
import '../../../../data/models/account_models.dart';
import '../../../../data/models/catalog_models.dart';

/// What the customer told the planner.
class PlannerCriteria {
  const PlannerCriteria({
    required this.eventType,
    required this.categoryIds,
    this.guestCount,
    this.area,
    this.eventDate,
    this.budgetMax,
    this.style,
  });

  final EventType eventType;
  final List<String> categoryIds;
  final int? guestCount;

  /// null = any area in Baghdad.
  final String? area;
  final DateTime? eventDate;

  /// Total budget for this service in IQD (null = not specified).
  final double? budgetMax;
  final String? style;
}

enum ReasonKind { match, info, warning }

class MatchReason {
  const MatchReason(this.kind, this.text);
  final ReasonKind kind;
  final String text;
}

class PlannerMatch {
  const PlannerMatch({required this.provider, required this.score, required this.reasons});
  final SawaProvider provider;
  final int score;
  final List<MatchReason> reasons;
}

class PlannerResult {
  const PlannerResult({required this.byCategory, required this.excluded});

  /// Ranked matches per requested category id (may be empty — honest).
  final Map<String, List<PlannerMatch>> byCategory;

  /// Providers left out, with the rule that excluded them.
  final List<PlannerMatch> excluded;
}

/// Explainable, rule-based matching — **not AI**. Every point in the score
/// comes from a rule the UI can show next to the result:
///
///  * category   — only providers of a requested category are considered;
///  * capacity   — a hall whose stated capacity is below the guest count is
///                 excluded; unknown capacity is shown as "غير متوفرة";
///  * area       — +3 when the provider lists the requested area;
///  * budget     — +2 when the known starting price (or offer) fits, −2 when
///                 above; unknown prices are neither rewarded nor hidden;
///  * data       — +1 for each of: real photos, listed packages, a price.
///
/// Missing data never counts as a match and never excludes a provider.
PlannerResult matchProviders(
  List<SawaProvider> providers,
  PlannerCriteria c, {
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  final byCategory = <String, List<PlannerMatch>>{for (final id in c.categoryIds) id: []};
  final excluded = <PlannerMatch>[];

  for (final p in providers) {
    if (!byCategory.containsKey(p.categoryId)) continue;
    final reasons = <MatchReason>[];
    var score = 0;
    var exclude = false;

    // Capacity (only meaningful for venues).
    if (c.guestCount != null && p.categoryId == 'halls') {
      if (p.capacity == null) {
        reasons.add(const MatchReason(ReasonKind.info, 'السعة غير متوفرة في بيانات المزود'));
      } else if (p.capacity! >= c.guestCount!) {
        score += 3;
        reasons.add(MatchReason(ReasonKind.match, 'تتسع لـ${p.capacity} ضيف (عددك ${c.guestCount})'));
      } else {
        exclude = true;
        reasons.add(MatchReason(ReasonKind.warning, 'السعة ${p.capacity} أقل من عدد ضيوفك'));
      }
    }

    // Area.
    if (c.area != null) {
      final hit = p.areas.any((a) => a.contains(c.area!) || c.area!.contains(a));
      if (hit) {
        score += 3;
        reasons.add(MatchReason(ReasonKind.match, 'في منطقة ${c.area}'));
      } else if (p.areas.isEmpty) {
        reasons.add(const MatchReason(ReasonKind.info, 'المنطقة غير محددة في بيانات المزود'));
      } else {
        reasons.add(MatchReason(ReasonKind.info, 'في ${p.areas.join('، ')}'));
      }
    }

    // Budget.
    final price = p.displayPrice(today);
    if (c.budgetMax != null) {
      if (price == null) {
        reasons.add(const MatchReason(ReasonKind.info, 'السعر غير متوفر — اسأل عنه بطلب تواصل'));
      } else if (price.from <= c.budgetMax!) {
        score += 2;
        reasons.add(MatchReason(
            ReasonKind.match, '${price.isOffer ? 'عرض' : 'يبدأ'} من ${formatIqd(price.from)} ضمن ميزانيتك'));
      } else {
        score -= 2;
        reasons.add(MatchReason(ReasonKind.warning, 'يبدأ من ${formatIqd(price.from)} — أعلى من ميزانيتك'));
      }
    }

    // Data completeness (helps the customer decide; never invented).
    if (p.cardImageUrl != null || p.galleryImages.isNotEmpty) score += 1;
    if (p.activePackages(today).isNotEmpty) {
      score += 1;
      reasons.add(MatchReason(ReasonKind.match, '${p.activePackages(today).length} باقة/عرض معروض'));
    }
    if (price != null) score += 1;

    final m = PlannerMatch(provider: p, score: score, reasons: reasons);
    (exclude ? excluded : byCategory[p.categoryId]!).add(m);
  }

  for (final list in byCategory.values) {
    list.sort((a, b) {
      final s = b.score.compareTo(a.score);
      return s != 0 ? s : a.provider.businessName.compareTo(b.provider.businessName);
    });
  }
  return PlannerResult(byCategory: byCategory, excluded: excluded);
}

/// Areas that actually appear in the data — the planner never offers an
/// area filter that cannot match anything.
List<String> knownAreas(List<SawaProvider> providers) {
  final set = <String>{};
  for (final p in providers) {
    for (final a in p.areas) {
      if (!a.contains('توصيل') &&
          !a.contains('إسطنبول') &&
          !a.contains('أربيل') &&
          !a.contains('كركوك') &&
          a != 'بغداد') {
        set.add(a);
      }
    }
  }
  final list = set.toList()..sort();
  return list;
}
