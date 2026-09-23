import 'package:flutter_test/flutter_test.dart';
import 'package:sawa/features/contact_request/data/contact_request_model.dart';

void main() {
  test('toJson omits "note" when null', () {
    final request = ContactRequest(
      providerId: 'hall_001',
      userName: 'زينب أحمد',
      userContact: '+9647701234567',
      createdAt: DateTime.utc(2026, 9, 22, 10, 30),
    );

    final json = request.toJson();

    expect(json['provider_id'], 'hall_001');
    expect(json['user_name'], 'زينب أحمد');
    expect(json['user_contact'], '+9647701234567');
    expect(json.containsKey('note'), isFalse);
    expect(json['created_at'], '2026-09-22T10:30:00.000Z');
  });

  test('toJson omits "note" when it is only whitespace', () {
    final request = ContactRequest(
      providerId: 'hall_001',
      userName: 'زينب أحمد',
      userContact: '+9647701234567',
      note: '   ',
      createdAt: DateTime.utc(2026, 9, 22),
    );

    expect(request.toJson().containsKey('note'), isFalse);
  });

  test('toJson includes a trimmed "note" when provided', () {
    final request = ContactRequest(
      providerId: 'hall_001',
      userName: 'زينب أحمد',
      userContact: '+9647701234567',
      note: '  أريد السعر لموعد 15 تشرين الثاني  ',
      createdAt: DateTime.utc(2026, 9, 22),
    );

    expect(
      request.toJson()['note'],
      'أريد السعر لموعد 15 تشرين الثاني',
    );
  });

  test('toJson never includes a provider phone number field', () {
    final request = ContactRequest(
      providerId: 'hall_001',
      userName: 'زينب أحمد',
      userContact: '+9647701234567',
      createdAt: DateTime.utc(2026, 9, 22),
    );

    // Locked rule (Skill Module 5): provider phone is never surfaced
    // anywhere. This model has no such field at all, and this test pins
    // that down at the JSON-shape level too.
    expect(request.toJson().keys, isNot(contains('provider_phone')));
    expect(request.toJson().keys, isNot(contains('phone_number')));
  });
}
