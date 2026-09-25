import 'json_utils.dart';

enum UserRole {
  customer,
  provider,
  admin;

  static UserRole parse(String? v) => switch (v) {
        'provider' => UserRole.provider,
        'admin' => UserRole.admin,
        _ => UserRole.customer,
      };
}

/// The signed-in user: `auth.users` + `public.profiles`.
class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.role,
    this.fullName,
    this.phone,
  });

  final String id;
  final String email;
  final UserRole role;
  final String? fullName;
  final String? phone;

  bool get isProvider => role == UserRole.provider;

  String get displayName => fullName ?? email.split('@').first;

  AppUser copyWith({String? fullName, String? phone}) => AppUser(
        id: id,
        email: email,
        role: role,
        fullName: fullName ?? this.fullName,
        phone: phone ?? this.phone,
      );
}

enum RequestStatus {
  newRequest,
  viewed,
  contacted,
  completed,
  cancelled;

  static RequestStatus parse(String? v) => switch (v) {
        'viewed' => RequestStatus.viewed,
        'contacted' => RequestStatus.contacted,
        'completed' => RequestStatus.completed,
        'cancelled' => RequestStatus.cancelled,
        _ => RequestStatus.newRequest,
      };

  String get dbValue => this == RequestStatus.newRequest ? 'new' : name;

  String get labelAr => switch (this) {
        RequestStatus.newRequest => 'جديد — لدى فريق SAWA',
        RequestStatus.viewed => 'تمت المشاهدة',
        RequestStatus.contacted => 'تم التواصل',
        RequestStatus.completed => 'مكتمل',
        RequestStatus.cancelled => 'ملغى',
      };
}

/// A row of `public.contact_requests` as its owner (or a forwarded
/// provider) can read it.
class ContactRequestRecord {
  const ContactRequestRecord({
    required this.id,
    required this.referenceCode,
    required this.status,
    required this.userName,
    required this.userContact,
    required this.createdAt,
    this.providerUuid,
    this.providerKey,
    this.note,
    this.forwardedAt,
  });

  final int id;
  final String referenceCode;
  final RequestStatus status;
  final String userName;
  final String userContact;
  final DateTime createdAt;
  final String? providerUuid;
  final String? providerKey;
  final String? note;
  final DateTime? forwardedAt;

  bool get canCancel => status == RequestStatus.newRequest || status == RequestStatus.viewed;

  factory ContactRequestRecord.fromJson(Map<String, dynamic> j) => ContactRequestRecord(
        id: intOrNull(j['id']) ?? 0,
        referenceCode: str(j['reference_code']) ?? '—',
        status: RequestStatus.parse(str(j['status'])),
        userName: str(j['user_name']) ?? '',
        userContact: str(j['user_contact']) ?? '',
        createdAt: dateOrNull(j['created_at']) ?? DateTime.now(),
        providerUuid: str(j['provider_uuid']),
        providerKey: str(j['provider_id']),
        note: str(j['note']),
        forwardedAt: dateOrNull(j['forwarded_to_provider_at']),
      );
}

/// Event types allowed by `event_inquiries_event_type_check`.
enum EventType {
  wedding,
  engagement,
  birthday,
  graduation,
  corporate,
  other;

  String get labelAr => switch (this) {
        EventType.wedding => 'زفاف',
        EventType.engagement => 'خطوبة',
        EventType.birthday => 'عيد ميلاد',
        EventType.graduation => 'تخرّج',
        EventType.corporate => 'مناسبة عمل',
        EventType.other => 'مناسبة أخرى',
      };

  static EventType parse(String? v) => EventType.values.firstWhere((e) => e.name == v, orElse: () => EventType.other);
}

enum InquiryStatus {
  open,
  inReview,
  closed,
  cancelled;

  static InquiryStatus parse(String? v) => switch (v) {
        'in_review' => InquiryStatus.inReview,
        'closed' => InquiryStatus.closed,
        'cancelled' => InquiryStatus.cancelled,
        _ => InquiryStatus.open,
      };

  String get labelAr => switch (this) {
        InquiryStatus.open => 'مفتوح — لدى فريق SAWA',
        InquiryStatus.inReview => 'قيد المراجعة',
        InquiryStatus.closed => 'مغلق',
        InquiryStatus.cancelled => 'ملغى',
      };
}

/// A row of `public.event_inquiries` (planner submission).
class EventInquiryRecord {
  const EventInquiryRecord({
    required this.id,
    required this.referenceCode,
    required this.eventType,
    required this.status,
    required this.createdAt,
    this.guestCount,
    this.area,
    this.eventDate,
    this.budgetMax,
    this.services = const [],
    this.notes,
  });

  final int id;
  final String referenceCode;
  final EventType eventType;
  final InquiryStatus status;
  final DateTime createdAt;
  final int? guestCount;
  final String? area;
  final DateTime? eventDate;
  final double? budgetMax;
  final List<String> services;
  final String? notes;

  bool get canCancel => status == InquiryStatus.open || status == InquiryStatus.inReview;

  factory EventInquiryRecord.fromJson(Map<String, dynamic> j) => EventInquiryRecord(
        id: intOrNull(j['id']) ?? 0,
        referenceCode: str(j['reference_code']) ?? '—',
        eventType: EventType.parse(str(j['event_type'])),
        status: InquiryStatus.parse(str(j['status'])),
        createdAt: dateOrNull(j['created_at']) ?? DateTime.now(),
        guestCount: intOrNull(j['guest_count']),
        area: str(j['area']),
        eventDate: dateOrNull(j['event_date']),
        budgetMax: numOrNull(j['budget_max']),
        services: (j['services'] is List) ? (j['services'] as List).whereType<String>().toList() : const [],
        notes: str(j['notes']),
      );
}

/// `public.get_provider_stats()` — every number is a real row count.
class ProviderStats {
  const ProviderStats({
    required this.viewsTotal,
    required this.viewsLast30Days,
    required this.requestsTotal,
    required this.requestsNew,
    required this.servicesActive,
    required this.servicesTotal,
  });

  final int viewsTotal;
  final int viewsLast30Days;
  final int requestsTotal;
  final int requestsNew;
  final int servicesActive;
  final int servicesTotal;

  factory ProviderStats.fromJson(Map<String, dynamic> j) => ProviderStats(
        viewsTotal: intOrNull(j['views_total']) ?? 0,
        viewsLast30Days: intOrNull(j['views_last_30_days']) ?? 0,
        requestsTotal: intOrNull(j['requests_total']) ?? 0,
        requestsNew: intOrNull(j['requests_new']) ?? 0,
        servicesActive: intOrNull(j['services_active']) ?? 0,
        servicesTotal: intOrNull(j['services_total']) ?? 0,
      );
}
