import 'package:flutter_test/flutter_test.dart';
import 'package:sawa/core/auth/auth_notifier.dart';
import 'package:sawa/core/router/app_router.dart';
import 'package:sawa/core/utils/errors.dart';
import 'package:sawa/core/utils/formatters.dart';
import 'package:sawa/data/models/account_models.dart';
import 'package:sawa/data/models/catalog_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException, PostgrestException;

void main() {
  group('formatters', () {
    test('IQD formatting and ranges', () {
      expect(formatIqd(750000), '750,000 د.ع');
      expect(formatRange(750000, 1000000), '750,000 – 1,000,000 د.ع');
      expect(formatRange(null, null), 'السعر غير متوفر');
      expect(displayPriceLabel(const DisplayPrice(from: 500000, isOffer: true)), 'عروض من 500,000 د.ع');
      expect(displayPriceLabel(const DisplayPrice(from: 10000, isOffer: false)), 'من 10,000 د.ع');
    });

    test('phone validation mirrors the server rule, incl. Arabic digits', () {
      expect(isValidPhone('07701234567'), isTrue);
      expect(isValidPhone('٠٧٧٠١٢٣٤٥٦٧'), isTrue);
      expect(normalizePhone('٠٧٧٠ ١٢٣'), '0770 123');
      expect(isValidPhone('+964 770 123 4567'), isTrue);
      expect(isValidPhone('abc'), isFalse);
      expect(isValidPhone('12345'), isFalse);
    });
  });

  group('router redirect rules', () {
    const guest = AuthState();
    const loading = AuthState(isLoading: true);
    const customer = AuthState(user: AppUser(id: 'c', email: 'c@x.iq', role: UserRole.customer));
    const provider = AuthState(user: AppUser(id: 'p', email: 'p@x.iq', role: UserRole.provider));

    test('splash', () {
      expect(resolveRedirect(path: '/splash', auth: loading), isNull);
      expect(resolveRedirect(path: '/splash', auth: guest), '/welcome');
      expect(resolveRedirect(path: '/splash', auth: customer), '/c/home');
      expect(resolveRedirect(path: '/splash', auth: provider), '/p/dashboard');
    });

    test('guests can browse and contact without an account', () {
      for (final p in ['/c/home', '/c/explore', '/c/provider/x', '/c/contact/x', '/c/planner', '/c/requests']) {
        expect(resolveRedirect(path: p, auth: guest), isNull, reason: p);
      }
    });

    test('provider portal is closed to guests and customers', () {
      expect(resolveRedirect(path: '/p/dashboard', auth: guest), '/login');
      expect(resolveRedirect(path: '/p/services', auth: customer), '/c/home');
      expect(resolveRedirect(path: '/p/dashboard', auth: provider), isNull);
    });

    test('providers are kept in their portal; signed-in users skip auth pages', () {
      expect(resolveRedirect(path: '/c/home', auth: provider), '/p/dashboard');
      expect(resolveRedirect(path: '/login', auth: customer), '/c/home');
      expect(resolveRedirect(path: '/signup', auth: provider), '/p/dashboard');
    });
  });

  group('friendlyError', () {
    test('maps server trigger errors to Arabic, never to success', () {
      expect(friendlyError(const PostgrestException(message: 'rate_limited')), contains('عدة طلبات'));
      expect(friendlyError(const PostgrestException(message: 'duplicate_request')), contains('قبل دقائق'));
      expect(friendlyError(const PostgrestException(message: 'invalid_contact')), contains('رقم الهاتف'));
      expect(friendlyError(const BackendUnavailable()), offlineMessage);
      expect(friendlyError(const AuthException('Invalid login credentials')), contains('غير صحيحة'));
      expect(friendlyError(Exception('boom')), contains('غير متوقع'));
    });
  });

  group('models', () {
    test('request status db mapping', () {
      expect(RequestStatus.parse('new'), RequestStatus.newRequest);
      expect(RequestStatus.newRequest.dbValue, 'new');
      expect(RequestStatus.parse('contacted').dbValue, 'contacted');
    });

    test('expired offers are hidden from customers', () {
      final p = SawaProvider(
        id: 'x',
        categoryId: 'halls',
        businessName: 'x',
        city: 'بغداد',
        status: ListingStatus.published,
        packages: [
          ProviderPackage(
              id: '1', providerId: 'x', title: 'old', priceFrom: 1, isOffer: true, validUntil: DateTime(2026, 1, 1)),
        ],
      );
      expect(p.activePackages(DateTime(2026, 9, 25)), isEmpty);
      expect(p.displayPrice(DateTime(2026, 9, 25)), isNull);
    });
  });
}
