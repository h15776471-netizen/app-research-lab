/// A single contact-request submission — maps to the `contact_requests`
/// Supabase table (insert-only from the client).
///
/// Source: sawa-technical-architecture.md §6. Deliberately holds only what
/// the 3-field form actually collects — never a provider phone number
/// (locked product decision), never anything beyond name/contact/note
/// (Skill Module 6: "Do not collect, log, or transmit anything beyond
/// what that form defines").
class ContactRequest {
  const ContactRequest({
    required this.providerId,
    required this.userName,
    required this.userContact,
    required this.createdAt,
    this.note,
  });

  final String providerId;
  final String userName;

  /// The USER's own contact info — how the sawa team reaches them back.
  /// NOT the provider's number. Required.
  ///
  /// Resolves SAWA_FINAL_MASTER_SPEC.md Conflict Register C1: the product
  /// spec's "لا رقم تواصل مباشر مطلوب لإرسال الطلب" refers to the
  /// provider's number (never required/shown), not the user's own, which
  /// the entire "نتابع طلبك" follow-up promise depends on.
  final String userContact;

  final String? note;
  final DateTime createdAt;

  /// ENGINEERING ASSUMPTION (not specified by any source doc): JSON keys
  /// below use snake_case to match conventional Postgres/Supabase column
  /// naming. If the real `contact_requests` table uses different column
  /// names, update this mapping — it does not change the Dart-side model.
  Map<String, dynamic> toJson() => {
        'provider_id': providerId,
        'user_name': userName,
        'user_contact': userContact,
        if (note != null && note!.trim().isNotEmpty) 'note': note!.trim(),
        'created_at': createdAt.toIso8601String(),
      };
}
