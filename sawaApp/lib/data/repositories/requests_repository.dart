import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/utils/errors.dart';
import '../models/account_models.dart';

class Submission {
  const Submission({required this.referenceCode, this.id});
  final String referenceCode;
  final int? id;
}

/// What the planner sends to `create_event_inquiry`.
class InquiryInput {
  const InquiryInput({
    required this.eventType,
    this.guestCount,
    this.area,
    this.eventDate,
    this.budgetMax,
    this.services = const [],
    this.style,
    this.notes,
    this.guestName,
    this.guestContact,
  });

  final EventType eventType;
  final int? guestCount;
  final String? area;
  final DateTime? eventDate;
  final double? budgetMax;
  final List<String> services;
  final String? style;
  final String? notes;
  final String? guestName;
  final String? guestContact;
}

/// Customer → SAWA requests. Every write goes through a SECURITY DEFINER RPC
/// that stamps identity server-side; guests get a reference code and can
/// never read requests back.
class RequestsRepository {
  RequestsRepository(this._client);

  final SupabaseClient? _client;
  SupabaseClient get _c => _client ?? (throw const BackendUnavailable());

  bool get isAvailable => _client != null;

  Future<Submission> submitContactRequest({
    required String providerId,
    required String name,
    required String contact,
    String? message,
    String? serviceId,
    int? inquiryId,
  }) async {
    final data = await _c.rpc('submit_contact_request', params: {
      'p_provider_id': providerId,
      'p_name': name.trim(),
      'p_contact': contact.trim(),
      'p_message': (message == null || message.trim().isEmpty) ? null : message.trim(),
      'p_inquiry_id': inquiryId,
      'p_service_id': serviceId,
    });
    final row = (data as List).first as Map<String, dynamic>;
    return Submission(referenceCode: row['reference_code'] as String);
  }

  Future<Submission> createInquiry(InquiryInput i) async {
    String? date(DateTime? d) => d == null
        ? null
        : '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final data = await _c.rpc('create_event_inquiry', params: {
      'p_event_type': i.eventType.name,
      'p_guest_count': i.guestCount,
      'p_city': 'بغداد',
      'p_area': i.area,
      'p_event_date': date(i.eventDate),
      'p_budget_min': null,
      'p_budget_max': i.budgetMax,
      'p_currency': 'IQD',
      'p_services': i.services,
      'p_style': i.style,
      'p_notes': i.notes,
      'p_guest_name': i.guestName,
      'p_guest_contact': i.guestContact,
    });
    final row = (data as List).first as Map<String, dynamic>;
    return Submission(
      referenceCode: row['reference_code'] as String,
      id: (row['id'] as num?)?.toInt(),
    );
  }

  /// RLS returns only the caller's own rows.
  Future<List<ContactRequestRecord>> myContactRequests(String userId) async {
    final data = await _c
        .from('contact_requests')
        .select('id, reference_code, status, user_name, user_contact, note, created_at, '
            'provider_uuid, provider_id, forwarded_to_provider_at')
        .eq('customer_id', userId)
        .order('created_at', ascending: false);
    return data.map(ContactRequestRecord.fromJson).toList();
  }

  Future<List<EventInquiryRecord>> myInquiries(String userId) async {
    final data =
        await _c.from('event_inquiries').select().eq('customer_id', userId).order('created_at', ascending: false);
    return data.map(EventInquiryRecord.fromJson).toList();
  }

  Future<void> cancelContactRequest(int id) => _c.from('contact_requests').update({'status': 'cancelled'}).eq('id', id);

  Future<void> cancelInquiry(int id) => _c.from('event_inquiries').update({'status': 'cancelled'}).eq('id', id);
}
