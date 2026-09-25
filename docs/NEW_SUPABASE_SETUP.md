# ربط SAWA بمشروع Supabase جديد — خطوة بخطوة

> هذا الدليل مكتوب للفريق. نفّذوا الخطوات **بالترتيب**، وبعد كل خطوة قارنوا النتيجة
> بـ«النتيجة المتوقعة». إذا ظهر شيء مختلف: **لا تصلحوه بأنفسكم** — انسخوا رسالة الخطأ
> كاملة وأرسلوها مع رقم الخطوة.

## ⚠️ قواعد قبل البدء

- **لا ترسلوا لأي أحد** (ولا لـClaude ولا لـChatGPT): Database Password، أو `service_role` / Secret key.
- المفتاح الوحيد الذي يدخل التطبيق هو **Publishable key** (أو `anon` public) + **Project URL**.
- لا تعدّلوا ولا تحذفوا شيئاً في مشروع Supabase **القديم**.
- الملفات تُنسخ **كاملة كما هي** — لا تعدّلوا أي سطر.

---

## الخطوة 1 — إنشاء المشروع

1. [supabase.com/dashboard](https://supabase.com/dashboard) ← **New project**.
2. Name: `sawa` — Region: الأقرب لكم (مثلاً Frankfurt `eu-central-1`).
3. اختاروا Database Password قوية واحفظوها عندكم فقط.
4. انتظروا حتى تنتهي التهيئة.

**أرسلوا:** رمز المشروع فقط (Project Settings ← General ← *Project ID*) — ليس كلمة المرور.

## الخطوة 2 — إعدادات الدخول (Auth)

Authentication ← Sign In / Providers ← **Email**:
- Enable Email provider: **ON**
- Confirm email: **OFF** (أثناء التطوير والاختبار فقط — نراجعه قبل الإطلاق)

## الخطوة 3 — قاعدة البيانات (3 ملفات)

SQL Editor ← **New query** ← الصق الملف كاملاً ← **Run**. ملف واحد في كل مرة، بهذا الترتيب:

| # | الملف في المستودع | النتيجة المتوقعة |
|---|---|---|
| 3.1 | `supabase/deploy/01_schema.sql` | `Success. No rows returned` |
| 3.2 | `supabase/deploy/02_storage.sql` | `Success. No rows returned` |
| 3.3 | `supabase/deploy/seed_providers.sql` | جدول بصفّين: `draft 2` و `published 15` |

- إذا فشل ملف: لا يُطبَّق منه شيء (كل ملف transaction مستقل) — أرسلوا الخطأ ولا تعيدوا التشغيل عشوائياً.
- إذا فشل **3.2** فقط برسالة فيها `must be owner`: هذا معروف في بعض مشاريع Supabase — أرسلوا الرسالة؛ باقي النظام يعمل ونحلّها بخطوة منفصلة.

## الخطوة 4 — التحقق

| # | الملف | النتيجة المتوقعة |
|---|---|---|
| 4.1 | `supabase/tests/verify_schema.sql` | أول صف: `SUMMARY` … `PHASE 1 SCHEMA OK` |
| 4.2 | `supabase/tests/rls_test.sql` | **رسالة خطأ** تحتوي `ALL_TESTS_PASSED (… checks)` ← هذا نجاح مقصود (الاختبار يمسح بياناته بنفسه) |

**أرسلوا:** صورة أو نص أول صف من 4.1، ونص الرسالة من 4.2.

## الخطوة 5 — تشغيل التطبيق على المشروع الجديد

Project Settings ← **API Keys**: انسخوا *Project URL* و *Publishable key* (يبدأ بـ `sb_publishable_` أو مفتاح `anon` القديم).

```powershell
cd sawaApp
flutter run -d chrome `
  --dart-define=SUPABASE_URL=https://<PROJECT_ID>.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=<PUBLISHABLE_KEY>
```

للنشر (Netlify أو غيره):

```powershell
flutter build web --release `
  --dart-define=SUPABASE_URL=https://<PROJECT_ID>.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=<PUBLISHABLE_KEY>
```

ثم يُرفع مجلد `sawaApp/build/web`.

**فحص سريع:** الرئيسية تعرض 6 قاعات، 5 تصوير، 4 ورد. افتحوا مزوداً ← «اطلب تواصل» ←
أرسلوا طلباً تجريبياً باسم `QA TEST` ← يجب أن يظهر **رقم مرجعي** مثل `SW-1A2B3C4D`.

> بدون `--dart-define` يعمل التطبيق للتصفح فقط (بيانات مضمّنة) ويعرض رسالة «غير متصل» عند الإرسال — هذا مقصود.

## الخطوة 6 — حساب الإدارة (فريق SAWA)

1. من التطبيق: أنشئوا حساباً عادياً بالبريد الذي سيدير SAWA.
2. في SQL Editor (بدّلوا البريد):

```sql
update public.profiles set role = 'admin'
where id = (select id from auth.users where email = 'YOUR_EMAIL');
```

النتيجة المتوقعة: `Success. 1 row affected`.

---

## عمليات يومية لفريق SAWA (SQL Editor)

**عرض الطلبات الجديدة:**
```sql
select c.reference_code, c.created_at, c.user_name, c.user_contact, c.note, p.business_name
from public.contact_requests c left join public.providers p on p.id = c.provider_uuid
where c.status = 'new' order by c.created_at desc;
```

**طلبات التخطيط الجديدة:**
```sql
select reference_code, created_at, event_type, guest_count, area, event_date, budget_max, services, guest_name, guest_contact, notes
from public.event_inquiries where status = 'open' order by created_at desc;
```

**تحويل طلب لمزود لديه حساب في التطبيق** (يظهر له في «الطلبات»):
```sql
update public.contact_requests set forwarded_to_provider_at = now()
where reference_code = 'SW-XXXXXXXX';
```

**نشر مزود سجّل بنفسه وأرسل ملفه للمراجعة:**
```sql
select id, business_name, category_id, area, submitted_at from public.providers where status = 'pending';
update public.providers set status = 'published' where id = '<ID>';
```

**حذف الطلب التجريبي بعد الفحص:**
```sql
delete from public.contact_requests where user_name like 'QA TEST%';
```

---

## تحديث بيانات المزودين لاحقاً

المصدر الوحيد: `provider-data/catalog/providers.v2.json` (كل حقل معه حالة: `source_only` / `unverified` / `missing`).
بعد أي تعديل:

```powershell
node supabase/scripts/build_catalog.mjs
```

يولّد `supabase/deploy/seed_providers.sql` و`sawaApp/assets/data/catalog.json` معاً، ثم شغّلوا
`seed_providers.sql` مرة أخرى في SQL Editor (آمن للتكرار).
