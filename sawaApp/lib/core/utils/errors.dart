import 'package:supabase_flutter/supabase_flutter.dart';

/// Thrown by repositories when a write needs Supabase but the app is
/// running in offline catalog mode.
class BackendUnavailable implements Exception {
  const BackendUnavailable();

  @override
  String toString() => offlineMessage;
}

const offlineMessage =
    'هذه النسخة غير متصلة بخادم SAWA حالياً، لذلك لا يمكن الإرسال أو تسجيل الدخول. التصفح يعمل بشكل طبيعي.';

/// Maps server errors (raised by the SAWA triggers/RPCs, or by Supabase Auth)
/// to honest Arabic messages. Never turns a failure into a success.
String friendlyError(Object error) {
  if (error is BackendUnavailable) return offlineMessage;
  if (error is AuthException) {
    final m = error.message.toLowerCase();
    if (m.contains('invalid login')) return 'البريد الإلكتروني أو كلمة المرور غير صحيحة.';
    if (m.contains('already registered') || m.contains('already been registered')) {
      return 'هذا البريد مسجّل مسبقاً — جرّب تسجيل الدخول.';
    }
    if (m.contains('email not confirmed')) return 'يرجى تأكيد بريدك الإلكتروني أولاً.';
    if (m.contains('password')) return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل.';
    if (m.contains('rate limit')) return 'محاولات كثيرة، انتظر قليلاً ثم حاول مجدداً.';
    return 'تعذّر إكمال العملية: ${error.message}';
  }
  final text = error is PostgrestException ? error.message : error.toString();
  const known = {
    'rate_limited': 'أرسلت عدة طلبات خلال وقت قصير. حاول بعد قليل.',
    'duplicate_request': 'أرسلت طلباً لهذا المزود قبل دقائق — فريقنا سيتواصل معك.',
    'invalid_contact': 'رقم الهاتف غير صحيح. اكتب رقماً عراقياً صحيحاً.',
    'invalid_name': 'يرجى كتابة الاسم.',
    'message_too_long': 'الرسالة طويلة جداً.',
    'provider_not_available': 'هذا المزود غير متاح حالياً.',
    'provider_required': 'المزود غير محدد.',
    'contact_required': 'يرجى إدخال رقم للتواصل.',
    'event_date_in_past': 'تاريخ المناسبة يجب أن يكون اليوم أو بعده.',
    'unknown_service_category': 'إحدى الخدمات المختارة غير معروفة.',
    'provider_account_required': 'هذه العملية لحسابات مزودي الخدمة فقط.',
    'invalid_status_transition': 'لا يمكن تغيير الحالة بهذه الطريقة.',
    'provider_suspended': 'الحساب التجاري موقوف — تواصل مع فريق SAWA.',
    'immutable_field': 'لا يمكن تعديل هذا الحقل.',
    'not_allowed': 'ليست لديك صلاحية لهذه العملية.',
    'duplicate key': 'لديك نشاط تجاري مسجّل مسبقاً.',
  };
  for (final e in known.entries) {
    if (text.contains(e.key)) return e.value;
  }
  if (text.contains('Failed host lookup') ||
      text.contains('SocketException') ||
      text.contains('ClientException') ||
      text.contains('XMLHttpRequest')) {
    return 'تعذّر الاتصال بالإنترنت. تحقّق من الاتصال وحاول مجدداً.';
  }
  return 'حدث خطأ غير متوقع، حاول مرة ثانية.';
}
