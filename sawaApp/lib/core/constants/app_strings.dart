/// Locked Arabic copy — never reword, shorten, or "improve" these strings.
///
/// Source: sawa-product-specification.md (locked Product Decisions),
/// SAWA_FINAL_MASTER_SPEC.md §36 (post-audit correction: the success
/// screen's reassurance line was changed from "...قريباً" to the
/// time-neutral wording below, per Master Spec Phase 20).
abstract final class AppStrings {
  /// Card + Provider Details badge. Literal, per locked Product Decision.
  static const reviewedBadge = 'تمت مراجعته من فريق sawa';

  /// Contact Success primary line. Literal, per locked Product Decision.
  static const contactFollowUp = 'نتابع طلبك ونساعدك بالتواصل مع المزوّد.';

  /// Contact Success secondary reassurance line.
  /// Corrected wording (Master Spec §36 point 2) — the original
  /// "فريقنا راح يتواصل وياك قريباً" edged toward an implied speed promise
  /// the team hasn't validated. Never restore "قريباً" here.
  static const contactReassurance = 'فريقنا بيتواصل وياك.';

  /// Fallback when url_launcher fails to open the provider's Instagram link.
  static const instagramLinkFailed = 'تعذّر فتح الرابط';

  static const categoryEmptyState = 'لا يوجد مزودون مطابقون حالياً.';
  static const contactSubmitError = 'ما كدرنا نرسل طلبك، حاول مرة ثانية.';
  static const homeWelcome = 'أهلاً بيك بـsawa. اختر الفئة التي تدوّر عليها.';
}
