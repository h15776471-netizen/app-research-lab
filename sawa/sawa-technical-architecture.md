# sawa — Technical Architecture
**من:** Claude #3 — Technical Architect → **إلى:** Claude #4 (Flutter Developer)
**Source of Truth:** Product Specification (Claude #2) — لم يتغيّر المنتج، هذا تنفيذ تقني فقط.
**القيود:** $0 budget · 3 أيام · Flutter/Dart · Design غير محسوم (Design-System Ready فقط)

---

## 1. TECHNICAL EXECUTIVE SUMMARY

- **بدون Backend مخصص.** بيانات المزودين Static JSON مُجمّع محلياً في التطبيق (asset) — القراءة فقط، لا حاجة لخادم.
- **طلبات التواصل (Contact Requests)** تحتاج نقطة كتابة واحدة بسيطة تصل لفريق sawa. الحل: **Supabase** (جدول واحد `contact_requests`, بدون Auth, Free Tier, بدون بطاقة ائتمان) — [RECOMMENDATION]. البديل الاحتياطي بدون أي إعداد تقني: **Google Form مُضمّن كرابط/WebView** — [RECOMMENDATION، fallback].
- **State Management:** Riverpod — بسيط، Testable، مناسب لـ3 أيام، بدون BuildContext معقّد.
- **Navigation:** `go_router` — Declarative، يدعم deep-ish flows بسيطة (Home → Category → Details → Contact → Success) بأقل كود.
- **Architecture:** MVVM مبسّط (Presentation + Repository)، **بدون** طبقة Domain منفصلة — لا مبرر لها في 5-6 شاشات.
- **أهم سبب لكل قرار:** كل قرار هنا يُفضّل الأبسط الذي يعمل فعلياً خلال 3 أيام بتكلفة $0، وليس "الأفضل نظرياً".

---

## 2. TECHNOLOGY STACK

### Frontend
- **Flutter (stable channel) + Dart**
- **State Management:** Riverpod (`flutter_riverpod`)
- **Navigation:** `go_router`
- **Architecture pattern:** MVVM مبسّط + Repository (بدون Domain layer)
- **Networking:** `http` package فقط — نحتاجه فقط لإرسال طلب التواصل إلى Supabase (REST بسيط عبر `supabase_flutter` أو حتى `http` مباشرة). القراءة (المزودون) لا تحتاج شبكة إطلاقاً لأنها JSON محلي.

### Backend
**[DECISION من الـConstraints: لا Paid Backend]. [RECOMMENDATION التقني:]**

هل نحتاج Backend فعلاً؟ **جزئياً — فقط لكتابة طلبات التواصل**، وليس لعرض المزودين.

- **لماذا لا Backend كامل:** بيانات المزودين لا تتغير كل دقيقة، وتُدار يدوياً من الفريق أصلاً (Product Spec). Static JSON يغطي هذا 100% بدون أي خادم.
- **لماذا نحتاج نقطة كتابة واحدة:** طلب التواصل يجب أن يصل لفريق sawa بشكل موثوق (وليس مجرد Toast محلي يختفي). خيار بدون أي backend (مثل فتح تطبيق البريد/واتساب) أقل موثوقية وأقل احترافية من "نتابع طلبك" الموعود في الـSpec.

**الخيار المقترح: Supabase (جدول واحد فقط)**
- **Cost:** $0
- **Free Tier:** مشروع Postgres مجاني، REST API تلقائي (PostgREST)، لا يتطلب بطاقة ائتمان للتسجيل، حد يومي/شهري لعدد الطلبات (Free tier) كافٍ جداً لحجم هاكاثون (عشرات-مئات الطلبات).
- **MVP Limit:** يكفي بسهولة — استخدام واحد فقط: `INSERT` في جدول واحد بدون Auth (Row Level Security policy تسمح بـ `insert` عام، وتمنع `select/update/delete` من العميل).
- **Fallback:** إن تعطّل الإعداد أو ضاق الوقت → **Google Form** (رابط مباشر أو مُضمّن في WebView) يرسل البيانات لـGoogle Sheet يراقبه الفريق يدوياً. صفر كود إضافي، صفر تبعية شبكة معقدة.

### Database
**[DECISION: تُدار بيانات المزودين يدوياً من فريق sawa — لا حساب دخول للمزوّد].**

- **بيانات المزودين (القراءة):** **Static JSON محلي** (asset مُجمّع مع التطبيق) — ليس Database فعلياً.
  - لماذا: 30-60 مزوّد إجمالاً (10-20 × 3 فئات)، لا تغييرات لحظية مطلوبة، صفر إعداد، صفر تبعية شبكة، يعمل حتى بدون إنترنت للتصفح.
  - **هل تكفي $0 و3 أيام؟** نعم بامتياز — هذا أبسط حل ممكن ومطابق تماماً لحجم البيانات.
- **طلبات التواصل (الكتابة):** جدول Supabase واحد (`contact_requests`) — أنظر قسم 8 للمقارنة الكاملة.

### Storage (الصور)
- **[RECOMMENDATION]:** صور المزودين تُستضاف كـ **روابط خارجية (Image URLs)** — إما رابط مباشر لصورة من حساب إنستغرام المزوّد (إن كان قابلاً للوصول العام)، أو رفع الصور يدوياً إلى **خدمة مجانية بدون بطاقة ائتمان** مثل:
  - **imgbb.com (Free API)** — رفع صور مجاني، يعطي رابط مباشر دائم، مناسب لـ30-60 صورة فقط. **Cost: $0 / Free Tier: يكفي لعدد الصور هذا / Fallback: تحميل الصور كـlocal assets داخل التطبيق نفسه إن فشل الرفع الخارجي.**
  - **Local assets داخل `assets/images/providers/`** — الخيار الأضمن والأبسط لـ3 أيام: **لا اعتماد على شبكة خارجية إطلاقاً**، الصور تُجمّع فعلياً في APK. العيب: تحديث صورة يتطلب إعادة بناء التطبيق — مقبول تماماً لهاكاثون.
  - **[OPEN DECISION]:** Local assets مقابل روابط خارجية — القرار يعتمد على: هل الفريق يفضّل تحديث الصور بدون rebuild (→ روابط خارجية) أم يفضّل ضمان عدم انقطاع الصور أثناء العرض المباشر (→ local assets)؟ **التوصية للعرض أمام اللجنة تحديداً: local assets — صفر مخاطرة اتصال إنترنت أثناء الـDemo.**

---

## 3. ARCHITECTURE

```
Presentation (Screens + Widgets)
        ↓ يستخدم
State (Riverpod Providers / Notifiers)
        ↓ يستدعي
Repository (ProviderRepository, ContactRequestRepository)
        ↓ يغلّف
Data Sources (JSON Local DataSource | Supabase Remote DataSource)
```

- **لا Domain layer منفصلة.** المشروع ≤6 شاشات ومنطق أعمال بسيط (فلترة، إرسال طلب) — إضافة UseCase classes هنا over-engineering فعلي مقابل الوقت المتاح.
- **Repository موجود رغم بساطة المشروع** — ليس ترفاً: يسمح لاحقاً بتبديل JSON محلي بـAPI حقيقي (Roadmap: بعد الهاكاثون) دون لمس الشاشات، ويجعل الـViewModel قابلاً للاختبار دون شبكة فعلية.
- **الاتجاه واحد فقط:** الشاشات لا تستورد أي شيء من `data/`، والـRepository لا يستورد أي Widget.

---

## 4. FLUTTER PROJECT STRUCTURE

```
lib/
├── main.dart
├── app.dart                          # MaterialApp.router + ProviderScope root
│
├── core/
│   ├── theme/
│   │   ├── app_colors.dart           # [DESIGN DECISION REQUIRED] — placeholders الآن
│   │   ├── app_text_styles.dart      # [DESIGN DECISION REQUIRED] — placeholders الآن
│   │   ├── app_spacing.dart          # tokens ثابتة (4/8/12/16/24...)
│   │   └── app_theme.dart            # ThemeData يجمع كل شيء أعلاه
│   ├── router/
│   │   └── app_router.dart           # go_router config + routes constants
│   ├── constants/
│   │   └── app_constants.dart        # أسماء الفئات، حدود، نصوص ثابتة عامة
│   └── widgets/                      # مكوّنات مشتركة عبر أكثر من Feature
│       ├── app_button.dart
│       ├── app_card.dart
│       ├── loading_view.dart
│       ├── error_view.dart
│       └── empty_state_view.dart
│
├── features/
│   ├── providers_list/               # فئة → قائمة مزودين + فلترة
│   │   ├── data/
│   │   │   ├── provider_model.dart
│   │   │   └── providers_repository.dart
│   │   ├── state/
│   │   │   └── providers_list_notifier.dart   # Riverpod
│   │   └── presentation/
│   │       ├── home_screen.dart
│   │       ├── category_screen.dart
│   │       └── widgets/
│   │           ├── provider_card.dart
│   │           └── category_tile.dart
│   │
│   ├── provider_details/
│   │   └── presentation/
│   │       └── provider_details_screen.dart
│   │
│   └── contact_request/
│       ├── data/
│       │   ├── contact_request_model.dart
│       │   └── contact_request_repository.dart   # Supabase أو Google Form fallback
│       ├── state/
│       │   └── contact_request_notifier.dart
│       └── presentation/
│           ├── contact_request_screen.dart
│           └── contact_success_screen.dart
│
└── data/
    └── local/
        └── assets/
            └── providers.json        # قاعدة البيانات الفعلية للـMVP

assets/
├── data/providers.json
└── images/providers/                 # إن اختير local assets للصور
```

**وظيفة كل مجلد:**
- `core/` — كل ما هو مشترك عبر التطبيق كله (Theme، Router، Widgets عامة). هنا بالتحديد يُطبَّق Design System لاحقاً بدون لمس منطق الشاشات.
- `features/<feature>/data` — Models + Repository لتلك الميزة فقط.
- `features/<feature>/state` — Riverpod Notifiers/Providers لتلك الميزة.
- `features/<feature>/presentation` — Screens + Widgets الخاصة بها فقط (لا تُشارَك خارج الميزة، وإلا تنتقل إلى `core/widgets`).
- `data/local/assets/providers.json` — "قاعدة البيانات" الفعلية لبيانات المزودين في هذا الإصدار.

---

## 5. SCREENS

| # | Screen | الغرض | البيانات المطلوبة | العناصر | الإجراءات | الشاشة التالية |
|---|---|---|---|---|---|---|
| 1 | **HomeScreen** | اختيار فئة (قاعات/مصورين/ديكور) | 3 فئات ثابتة | 3 Category Tiles | الضغط على فئة | CategoryScreen |
| 2 | **CategoryScreen** | تصفح/فلترة مزودي فئة معيّنة | قائمة Provider من JSON مفلترة بالفئة | AppBar + Search/Filter bar (بسيط) + قائمة Provider Cards + Empty State | فتح بطاقة مزوّد | ProviderDetailsScreen |
| 3 | **ProviderDetailsScreen** | عرض تفاصيل مزوّد كاملة | Provider واحد (name, images, price range, description, instagram link, "reviewed" badge) | صور، معلومات أساسية، رابط إنستغرام خارجي، زر "طلب تواصل" | فتح رابط إنستغرام (خارجي) / الضغط "طلب تواصل" | ContactRequestScreen |
| 4 | **ContactRequestScreen** | إدخال بيانات طلب التواصل | اسم المستخدم، رقم هاتف/وسيلة تواصل، ملاحظة اختيارية | فورم بسيط (2-3 حقول) + زر إرسال | إرسال الطلب (إلى Supabase/Google Form) | ContactSuccessScreen |
| 5 | **ContactSuccessScreen** | تأكيد صادق أن الطلب استُلم | لا شيء (نص ثابت) | رسالة "نتابع طلبك ونساعدك بالتواصل مع المزوّد" + زر رجوع للرئيسية | رجوع للـHome | HomeScreen |

**لا شاشات إضافية.** لا Login، لا Onboarding، لا Splash معقّد (Splash بسيط جداً إن لزم لتحميل JSON فقط).

### Navigation Flow
```
HomeScreen
   ↓ (اختيار فئة)
CategoryScreen
   ↓ (فتح بطاقة)
ProviderDetailsScreen
   ↓ (طلب تواصل)
ContactRequestScreen
   ↓ (إرسال ناجح)
ContactSuccessScreen
   ↓ (رجوع)
HomeScreen
```

---

## 6. DATA MODEL

### `Provider` (النموذج الأساسي)

| Field | Type | Required/Optional | مثال | الغرض |
|---|---|---|---|---|
| `id` | String | Required | `"hall_001"` | معرّف فريد للربط (routing, key) |
| `name` | String | Required | `"قاعة الماسة"` | اسم المزوّد |
| `category` | enum String (`hall` \| `photography` \| `decor`) | Required | `"hall"` | الفلترة حسب الفئة |
| `images` | List\<String\> | Required (≥1) | `["assets/images/providers/hall_001_1.jpg"]` | صور البطاقة والتفاصيل |
| `priceRangeText` | String? | Optional | `"من 500 إلى 1500 ألف دينار"` | نطاق سعري تقريبي إن توفر (نص حر وليس رقم دقيق — Product Spec: "إن توفر") |
| `shortDescription` | String? | Optional | `"قاعة أفراح وسط بغداد، سعة 300 شخص"` | نص مختصر في البطاقة |
| `instagramUrl` | String | Required | `"https://instagram.com/almasa_hall"` | رابط المصدر الأصلي — **لا يُحجب أبداً** (قرار منتج ثابت) |
| `city` | String | Required (ثابتة الآن) | `"بغداد"` | مطابقة للنطاق الجغرافي الحالي فقط، جاهزة للتوسع لاحقاً |
| `reviewedBySawa` | bool | Required (ثابت `true`) | `true` | لعرض شارة "تمت مراجعته من فريق sawa" — **لا تُستخدم كلمة "موثّق" في أي نص UI مرتبط بهذا الحقل** |

**لم تُضف:** rating/reviews عددية (لا يوجد نظام تقييمات في MVP)، availability/calendar (خارج النطاق)، contact phone مباشر (قرار منتج: لا يُعرض رقم مباشر على البطاقة).

### `ContactRequest`

| Field | Type | Required/Optional | مثال | الغرض |
|---|---|---|---|---|
| `providerId` | String | Required | `"hall_001"` | ربط الطلب بالمزوّد |
| `userName` | String | Required | `"زينب أحمد"` | اسم مُرسل الطلب |
| `userContact` | String | Required | `"+9647701234567"` | وسيلة تواصل الفريق مع المستخدم (ليس مع المزوّد مباشرة) |
| `note` | String? | Optional | `"أريد السعر لموعد 15 تشرين الثاني"` | ملاحظة حرة |
| `createdAt` | DateTime (server-side أو client ISO string) | Required | `2026-09-22T10:30:00Z` | ترتيب/متابعة الطلبات يدوياً من الفريق |

---

## 7. PROVIDER DATA PIPELINE

```
Instagram (جمع يدوي من الفريق)
   ↓
Google Sheet / Excel (عمود لكل Field أعلاه — سهل التعبئة الجماعية)
   ↓  (Export)
CSV
   ↓  (سكربت تحويل بسيط — Python/Node قصير، أو تحويل يدوي لعدد صغير كهذا)
providers.json  (مصفوفة Provider objects)
   ↓
assets/data/providers.json  (يُجمَّع مع Flutter build)
   ↓
ProvidersRepository يقرأه عبر rootBundle.loadString()
   ↓
Provider Cards في الواجهة
```

**التفاصيل:**
- **أفضل format:** JSON (مصفوفة كائنات) — لا حاجة لـCSV parsing داخل Flutter نفسه، التحويل يحدث مرة واحدة خارج التطبيق.
- **طريقة الـimport:** ملف `providers.json` واحد يُستبدل كاملاً عند كل تحديث بيانات (لا حاجة لدمج تلقائي — الحجم صغير جداً: 30-60 عنصر).
- **إضافة مزوّد جديد:** يُضاف سطر جديد في الـGoogle Sheet → يُعاد تصدير/تحويل الملف كاملاً → يُستبدل `providers.json` → **rebuild** للتطبيق (لا حاجة لتشغيل خادم أو نشر جديد معقّد؛ لهاكاثون هذا مقبول تماماً).
- **تحديث بيانات مزوّد:** نفس الآلية — تعديل في الـSheet ثم إعادة تصدير كامل الملف.
- **Missing data:** كل حقل `Optional` في الـModel (`priceRangeText`, `shortDescription`) يُعرض بشرط `if (value != null)` في الواجهة — **لا نص "غير متوفر" مزعج، فقط إخفاء الحقل**. الحقول `Required` (خصوصاً `images` و`instagramUrl`) **يجب** أن تكون مكتملة قبل إدخال أي مزوّد في الملف — يُتحقق منها يدوياً أثناء التحويل (لا تحقق آلي معقّد مطلوب لهذا الحجم).
- **تجنّب تعديل الكود عند إضافة مزوّد:** لأن القراءة كلها عبر `providers.json` كملف بيانات منفصل عن الكود — إضافة/تعديل مزوّد لا يلمس أي ملف `.dart` إطلاقاً، فقط الـasset، ثم rebuild.

---

## 8. DATABASE DECISION

**السؤال الفعلي هنا ليس "أي قاعدة بيانات لعرض المزودين؟" (الجواب: JSON محلي، محسوم في القسم 2) بل "أين تُخزَّن طلبات التواصل؟"**

### Option A — Supabase (جدول واحد، بدون Auth)
- **$0?** نعم، Free tier بدون بطاقة ائتمان.
- **Setup time:** ~30-60 دقيقة (إنشاء مشروع، جدول واحد، RLS policy للـinsert العام فقط).
- **Flutter integration:** بسيطة عبر `supabase_flutter` أو حتى `http.post` مباشر إلى REST endpoint التلقائي.
- **Scalability:** أكثر مما نحتاج بكثير لهذا الحجم — غير مهم الآن.
- **Complexity:** منخفضة إن اقتصرت على جدول واحد فقط بدون Auth/Storage/Realtime.
- **Suitability for 3-day MVP:** ✅ جيدة — تعطي فريق sawa **لوحة بيانات فعلية** (Supabase Table Editor) لمتابعة الطلبات فوراً بدون بناء أي Admin UI.

### Option B — Google Form (fallback بدون أي كود Backend)
- **$0?** نعم.
- **Setup time:** ~10 دقائق.
- **Flutter integration:** إما فتح رابط الفورم في متصفح/WebView خارجي (لا يُبقي المستخدم داخل تصميم sawa)، أو `http.post` مباشر إلى Google Form endpoint (ممكن تقنياً، هش قليلاً لتغييرات Google لاحقاً).
- **Scalability:** كافية جداً لهذا الحجم.
- **Complexity:** أدنى خيار ممكن.
- **Suitability for 3-day MVP:** ✅ ممتاز كـ**خطة بديلة سريعة** إن تعطّل إعداد Supabase أو ضاق الوقت في اليوم الأخير — لكنه أضعف من ناحية تجربة المستخدم (خروج من التصميم الموحد).

### Option C — لا شيء عن بُعد؛ تخزين محلي فقط على جهاز المستخدم (SharedPreferences/SQLite محلي)
- **$0?** نعم.
- **Setup time:** منخفض جداً.
- **Flutter integration:** بسيطة جداً (`shared_preferences` أو `sqflite`).
- **Scalability:** **غير مناسب إطلاقاً** — الطلب يبقى حبيس جهاز المستخدم ولا يصل لفريق sawa أبداً، وهذا يناقض القيمة الأساسية للمنتج ("نتابع طلبك"). **مرفوض.**

**القرار: Option A (Supabase) هو الأساسي، Option B (Google Form) هو الـFallback الرسمي إن فشل A خلال اليوم الأول.**
لا خدمة مدفوعة اقتُرحت في أي من الخيارات.

---

## 9. SEARCH & FILTER

**[DECISION من Product Spec]: "بحث/فلترة أساسية (حسب الفئة)" فقط — لا فلترة مدينة/سعر معقّدة (المدينة ثابتة = بغداد، والسعر نطاق نصي وليس رقماً قابلاً للفرز بدقة).**

- **Local search فقط** — البيانات كلها محمّلة في الذاكرة من JSON (30-60 عنصر)، لا داعٍ لأي طلب شبكة للفلترة أو البحث.
- **الفلترة الفعلية في MVP:** حسب الفئة فقط (تحدث أصلاً عبر التنقل بين HomeScreen → CategoryScreen، وليست عنصر UI فلترة إضافي داخل الشاشة).
- **[RECOMMENDATION اختياري بسيط إن بقي وقت]:** حقل بحث نصي بسيط داخل `CategoryScreen` يبحث في `name` فقط (تصفية بسيطة بـ`.contains()` على القائمة المحمّلة، لا Backend search). هذا **Should Have** وليس Must — إن ضاق الوقت يُحذف بدون أي أثر معماري (لا يوجد اعتماد عليه في بقية التطبيق).
- **الترتيب:** ترتيب ثابت حسب ترتيب الإدخال في `providers.json` — لا حاجة لخوارزمية ترتيب (لا Rating رقمي موجود لترتيب عليه).
- **حالة عدم وجود نتائج:** `EmptyStateView` عامة (موجودة في `core/widgets`) — نص بسيط وصادق مثل "لا يوجد مزودون مطابقون حالياً" (وليس رسالة خطأ تقنية).

---

## 10. CONTACT REQUEST

**[DECISION من Product Spec]: لا Booking Engine، لا رقم تواصل مباشر، الطلب يمر عبر sawa فقط.**

- **User input:** اسم المستخدم، وسيلة تواصل (رقم هاتف)، ملاحظة اختيارية.
- **Data stored:** كائن `ContactRequest` (القسم 6) يُرسَل إلى Supabase (Option A) أو Google Form (Fallback).
- **Submission:** زر إرسال واحد → حالة تحميل بسيطة (Loading) → نجاح/فشل.
  - عند الفشل (لا إنترنت/خطأ خادم): رسالة خطأ صادقة + زر "إعادة المحاولة" — **لا** نص يوحي بأن الطلب وصل إن لم يصل فعلياً (هذا يخالف فلسفة الصدق في المنتج).
- **Success state:** الانتقال إلى `ContactSuccessScreen` مع النص الثابت المقرر: "نتابع طلبك ونساعدك بالتواصل مع المزوّد."
- **Team notification/process:** **لا أتمتة مطلوبة** (Product Spec: "Later" فقط). الفريق يراقب Supabase Table Editor مباشرة (أو Google Sheet في حال Fallback) يدوياً. **لا نبني** أي Email/SMS notification تلقائي — خارج نطاق الـ3 أيام و$0 budget فعلياً (سيتطلب خدمة إشعارات إضافية).

---

## 11. STATE MANAGEMENT

**القرار: Riverpod (flutter_riverpod)**، بدل Provider/Bloc/GetX.

**لماذا:**
- Testable بدون `BuildContext` — مهم لاختبار منطق الفلترة وحالة الإرسال بسرعة.
- Async support جاهز (`FutureProvider`/`AsyncNotifier`) يناسب تحميل JSON وإرسال طلب الشبكة مباشرة دون كتابة loading/error booleans يدوياً.
- منحنى تعلّم أخف من Bloc، ووقت الإعداد أقل — مهم فعلياً في 3 أيام مقارنة بضخامة boilerplate الـBloc لمشروع بهذا الحجم.
- فريق صغير (1-3 مطورين) — لا حاجة لصرامة Bloc الإضافية التي تفيد الفرق الكبيرة أكثر.

**التوزيع:**
- **Global state:** لا يوجد فعلياً شيء عالمي معقّد في هذا MVP (لا Auth، لا مستخدم مسجّل). القائمة الكاملة للمزودين (من JSON) يمكن اعتبارها شبه-عالمية عبر `FutureProvider` واحد يُحمَّل مرة ويُخزَّن (cache تلقائي من Riverpod).
- **Feature state:** `providersListNotifier` (فلترة الفئة + البحث النصي إن أُضيف)، `contactRequestNotifier` (حالة الفورم والإرسال).
- **Local UI state:** حقول الفورم البسيطة (`TextEditingController`) تبقى `setState`/محلية داخل الـWidget — لا داعي لرفعها إلى Riverpod.
- **Loading/Error/Empty:** يُمثَّل كنموذج حالة واحد صريح لكل Notifier (وفق النمط الموصى به: sealed class أو `AsyncValue<T>` الجاهزة في Riverpod نفسها) — **ليس** متغيرات bool/nullable متناثرة.

---

## 12. DESIGN-SYSTEM READY ARCHITECTURE

**لا قرار تصميم هنا — فقط بنية استقبال جاهزة.**

| العنصر | المكان | الحالة الحالية |
|---|---|---|
| Theme (ThemeData) | `core/theme/app_theme.dart` | placeholder يجمع الملفات أدناه |
| Colors | `core/theme/app_colors.dart` | **[DESIGN DECISION REQUIRED]** — يُستخدم مؤقتاً لون محايد (رمادي/أبيض) حتى يصل قرار الهوية البصرية |
| Typography | `core/theme/app_text_styles.dart` | **[DESIGN DECISION REQUIRED]** — يُستخدم Font النظام الافتراضي مؤقتاً |
| Spacing | `core/theme/app_spacing.dart` | tokens ثابتة قابلة للاستخدام فوراً (4, 8, 12, 16, 24, 32) — لا تحتاج قرار تصميم لأنها قياسية |
| Border radius | `core/theme/app_theme.dart` (ضمن CardTheme/ButtonTheme) | قيمة placeholder واحدة موحّدة (مثلاً 12) تُستخدم من مكان واحد فقط |
| Reusable Cards | `core/widgets/app_card.dart` | مبني، يستقبل الألوان/الأنماط من `Theme.of(context)` وليس Hardcoded داخل الويدجت |
| Buttons | `core/widgets/app_button.dart` | نفس المبدأ — لا لون مكتوب داخل الملف نفسه |
| Inputs | `core/widgets/` (يُضاف عند الحاجة في شاشة الفورم) | نفس المبدأ |

**القاعدة الإلزامية على أي مطوّر (Claude #4):** أي Widget في `features/` يجب أن يقرأ الألوان/الخطوط عبر `Theme.of(context)` أو عبر `core/theme/` tokens — **صفر Hardcoded colors/fonts داخل ملفات الشاشات**. هذا وحده يكفي لجعل تطبيق Design System لاحقاً عملية استبدال ملفين (`app_colors.dart`, `app_text_styles.dart`) دون لمس أي شاشة.

---

## 13. IMAGE HANDLING

- **Image source:** حسب القرار في القسم 2 — **[OPEN DECISION]** بين local assets (موصى به للـDemo) وروابط خارجية.
- **Caching:**
  - إن كانت الصور **local assets**: لا حاجة لأي caching إضافي (Flutter يحمّلها من الحزمة مباشرة).
  - إن كانت **روابط خارجية**: استخدام `cached_network_image` (package مجاني، Open Source) — **Cost: $0**. يمنع إعادة تحميل نفس الصورة عند كل rebuild/scroll، ويعرض placeholder أثناء التحميل تلقائياً.
- **Loading:** `CachedNetworkImage` مع `placeholder:` بسيط (Shimmer أو لون رمادي ثابت — بدون Hardcoded تصميم نهائي، فقط placeholder وظيفي).
- **Error:** `errorWidget:` أيقونة/صورة افتراضية عامة عند فشل تحميل صورة مزوّد (لا تنهار البطاقة كاملة).
- **Optimization:** ضغط الصور **يدوياً قبل الإدخال** إلى `providers.json`/الـassets (أداة مجانية بسيطة مثل TinyPNG أو ضغط محلي) — لا حاجة لأي pipeline ضغط آلي داخل التطبيق نفسه لهذا الحجم من البيانات.

**التوصية النهائية:** local assets للعرض المباشر أمام اللجنة (صفر مخاطرة انقطاع إنترنت)، مع الإبقاء على `cached_network_image` كتبعية جاهزة في `pubspec.yaml` إن قرر الفريق التبديل لروابط خارجية لاحقاً بسهولة.

---

## 14. SECURITY

**الحد الأدنى فقط — لا Security architecture ضخمة لمشروع بهذا الحجم وبدون Auth حقيقي.**

- **API keys:** مفتاح Supabase العام (anon key) — **[RECOMMENDATION]:** يوضع في متغير بيئة عبر `--dart-define` أو ملف `.env` **غير مرفوع لـGitHub** (يُضاف لـ`.gitignore` فوراً). anon key من Supabase مصمَّم أصلاً ليكون على العميل، لكن **لا يُكتب مباشرة داخل الكود المرفوع للمستودع العام** كعادة نظيفة.
- **Environment variables:** ملف `.env.example` يُرفع (بدون قيم حقيقية) ليعرف أي مطوّر جديد الحقول المطلوبة؛ الملف الفعلي `.env` محلي فقط.
- **User contact information:** بيانات المستخدم المُرسلة في طلب التواصل (اسم، رقم هاتف) تُخزَّن في Supabase فقط — **RLS policy تمنع القراءة العامة (`select`) من العميل**، يسمح فقط بـ`insert`. لا يستطيع أي مستخدم آخر قراءة طلبات الآخرين عبر التطبيق.
- **Database rules:** جدول `contact_requests` — `insert: true` للجميع (بدون auth)، `select/update/delete: false` للعميل بالكامل (الفريق يراقب من لوحة Supabase مباشرة بحساب المشروع، وليس عبر التطبيق).
- **Public provider information:** بيانات المزودين (JSON) عامة بطبيعتها ومقصودة للعرض — لا حاجة لأي حماية هنا إطلاقاً.

**لا نحتاج:** Authentication حقيقي، Encryption إضافي، Rate limiting مخصص (Supabase free tier يوفر حداً كافياً ضمنياً لهذا الحجم).

---

## 15. PERFORMANCE

**فقط القرارات المهمة فعلياً — لا Premature Optimization.**

- **Image caching:** موضّح في القسم 13.
- **Lazy loading:** استخدام `ListView.builder` (وليس `ListView` مع قائمة كاملة مبنية دفعة واحدة) لقوائم المزودين — قرار قياسي بسيط، ضروري حتى لـ30-60 عنصر لتفادي إعادة بناء غير ضرورية.
- **List rendering:** كل `ProviderCard` يجب أن تكون `const` حيث أمكن (خصوصاً الأجزاء الثابتة من التصميم) لتقليل rebuilds.
- **Unnecessary rebuilds:** استخدام Riverpod's `select` عند الحاجة لقراءة حقل واحد فقط من حالة أكبر (مثال: قراءة فقط `isLoading` بدل كامل State object) — يمنع rebuild كامل الشاشة عند تغيّر جزء غير مرتبط.
- **Data loading:** تحميل `providers.json` **مرة واحدة** عند بدء التطبيق أو أول دخول لـCategoryScreen (Cache عبر Riverpod `FutureProvider` — لا يُعاد تحميل الملف من الـassets عند كل تنقل).

**لا نحتاج:** أي تحسين إضافي (Isolates، Pagination حقيقي، إلخ) — حجم البيانات صغير جداً ليبرر ذلك.

---

## 16. TESTING

**الحد الأدنى — الأولوية لما قد يكسر العرض المباشر فعلياً، وليس تغطية شاملة.**

### Unit
- `ProvidersRepository`: اختبار تحليل JSON صحيح → قائمة `Provider` صحيحة (خصوصاً الحقول Optional تُعالَج بدون كراش عند غيابها).
- `ContactRequestRepository`: اختبار بناء الـPayload الصحيح المُرسَل للخادم (بدون إرسال فعلي — mock).
- منطق الفلترة حسب الفئة (دالة صافية بسيطة، سهلة الاختبار بدون Widget).

### Widget
- `ProviderCard`: يعرض البيانات الصحيحة، ولا ينهار عند حقول Optional فارغة (`priceRangeText == null`).
- `ContactRequestScreen`: زر الإرسال معطّل عندما تكون الحقول المطلوبة فارغة (منع إرسال طلب ناقص).
- `EmptyStateView`: تظهر فعلياً عند قائمة فارغة (فئة بدون نتائج بحث).

### Integration
**أهم User Flow واحد يجب اختباره فعلياً قبل العرض:**
> HomeScreen → اختيار فئة → CategoryScreen → فتح بطاقة → ProviderDetailsScreen → طلب تواصل → تعبئة الفورم → إرسال → ContactSuccessScreen

هذا هو الـFlow الذي تراه اللجنة مباشرة — أي كسر فيه يفشل الـDemo بالكامل، لذا هو الأولوية القصوى المطلقة فوق أي اختبار آخر في هذه القائمة.

---

## 17. 3-DAY EXECUTION PLAN

### DAY 1 — Foundation + Architecture + Data + Navigation
- Project setup (Flutter project, dependencies، `.gitignore`، هيكل المجلدات من القسم 4).
- `core/theme/` بـplaceholders، `core/router/` بكل المسارات الخمسة (حتى لو الشاشات فارغة مؤقتاً).
- تحويل بيانات Instagram → Google Sheet → `providers.json` (يبدأ بالتوازي من عضو آخر في الفريق، لا يعتمد على الكود).
- `Provider` model + `ProvidersRepository` (قراءة JSON) + اختبار Unit أساسي.
- إعداد Supabase (مشروع + جدول `contact_requests` + RLS policy) — أو تجهيز Google Form كخطة بديلة جاهزة من الآن.
- **Definition of Done (نهاية اليوم 1):** التطبيق يفتح، Navigation بين الشاشات الخمس تعمل (حتى لو محتوى فارغ)، `providers.json` يُقرأ بنجاح ويُطبع عدد العناصر في الـconsole.

### DAY 2 — Core Screens + Provider Browsing + Details + Search/Filter
- `HomeScreen` (3 فئات فعلية).
- `CategoryScreen` (قائمة `ProviderCard` حقيقية من الـRepository، فلترة الفئة تعمل، Empty State).
- `ProviderDetailsScreen` (كل الحقول، رابط إنستغرام فعلي قابل للفتح، شارة "تمت مراجعته من فريق sawa").
- البحث النصي البسيط (إن بقي وقت — Should Have).
- **Definition of Done (نهاية اليوم 2):** يمكن تصفّح الفئات الثلاث بالكامل بصور وبيانات حقيقية من طرف إلى طرف حتى صفحة التفاصيل.

### DAY 3 — Contact Flow + Polish + Testing + Bug Fixing + Demo Prep
- `ContactRequestScreen` + `ContactRequestRepository` (إرسال فعلي لـSupabase) + `ContactSuccessScreen`.
- اختبار الـIntegration flow الكامل (القسم 16) — **أولوية قصوى**.
- Bug fixing عام + تحسينات بصرية سريعة ضمن الـtheme الموجود (بدون قرارات تصميم جديدة).
- تجهيز جهاز/محاكي للعرض المباشر + تأكيد عمل التطبيق **بدون إنترنت لتصفح المزودين** (إن كانت الصور local assets) والتحقق من إرسال طلب تواصل تجريبي فعلي يصل فعلاً لـSupabase/Google Sheet.
- **Definition of Done (نهاية اليوم 3):** الـFlow الكامل من القسم 16 يعمل بدون كراش، مرتين متتاليتين على الأقل، على الجهاز الذي سيُستخدم فعلياً في العرض.

**Dependencies:** اليوم 2 يعتمد على اكتمال `ProvidersRepository` من اليوم 1. اليوم 3 يعتمد على اكتمال `ProviderDetailsScreen` (لوجود زر "طلب تواصل"). **جمع بيانات Instagram → JSON يجب أن يبدأ من ساعة الصفر بالتوازي مع الكود، وليس بعده** — هو الحرج الحقيقي (Critical Path) لأن كل شاشة تنتظره.

---

## 18. TEAM WORK SPLIT

### Solo
اليوم 1: Foundation كاملة. اليوم 2: كل الشاشات بالترتيب. اليوم 3: Contact flow ثم اختبار/Polish. لا تفرّع — تنفيذ خطّي بالكامل وفق القسم 17.

### 2 Developers
- **Dev A:** `core/` (theme, router, widgets مشتركة) + `providers_list` + `provider_details` (كل شاشات العرض/التصفح).
- **Dev B:** `contact_request` (Model, Repository, Notifier, الشاشتان) + إعداد Supabase/Google Form + Testing.
- **نقطة التقاء إلزامية نهاية اليوم 1:** الاتفاق على `Provider` و`ContactRequest` models قبل أي عمل موازٍ فعلي، لأن كلا المسارين يعتمدان عليها.

### 3 Developers
- **Dev A:** نفس الأعلى (عرض/تصفح).
- **Dev B:** نفس الأعلى (Contact flow + Backend integration).
- **Dev C:** `core/theme/` + `core/widgets/` (Cards, Buttons, Loading/Error/Empty states) + كل الـTesting (Unit/Widget/Integration) + مساعدة في تحويل بيانات Instagram → JSON.
- **يمكن تنفيذها بالتوازي فعلياً:** الثلاثة يعملون من اليوم 1 بمجرد الاتفاق على الـModels والـRouter (نصف يوم تنسيق أولي، ثم عمل متوازٍ حقيقي).

---

## 19. GITHUB WORKFLOW

**بسيط جداً — لا نريد تعقيداً في 3 أيام.**

- **Branches:** `main` (يعمل دائماً) + فرع واحد لكل عضو: `dev/<name>` أو `feature/<feature-name>` (مثلاً `feature/contact-request`).
- **Commits:** رسائل قصيرة وواضحة بالإنجليزية أو العربية، بصيغة: `feat: add provider card widget`, `fix: category filter crash`.
- **Pull:** `git pull origin main` قبل بدء أي جلسة عمل، يومياً على الأقل.
- **Merge:** Pull Request بسيط إلى `main` بعد التأكد أن الكود يعمل محلياً (لا CI معقّد مطلوب لهاكاثون) — مراجعة سريعة من عضو آخر إن أمكن، أو Merge مباشر إن كان الوقت ضيقاً جداً في اليوم الأخير.
- **Naming:** أسماء فروع بالإنجليزية دائماً حتى لو الفريق يتواصل بالعربية (تفادي مشاكل الترميز في بعض الأدوات).

**لا نريد:** Git Flow كامل، Release branches، Conventional Commits الصارمة، CI/CD pipelines.

---

## 20. MVP CUT LIST

### MUST KEEP
- الشاشات الخمس (القسم 5) كاملة.
- `providers.json` بـ10-20 مزوّد حقيقي لكل فئة (Success Criteria من Product Spec نفسه).
- رابط إنستغرام ظاهر دائماً (قرار منتج غير قابل للتفاوض).
- إرسال طلب التواصل يصل فعلياً لمكان يراه الفريق (Supabase أو Google Form — أحدهما إلزامي).
- نصوص "تمت مراجعته من فريق sawa" و"نتابع طلبك..." كما هي حرفياً (قرار منتج).

### SIMPLIFY
- البحث النصي (القسم 9) — إن ضاق الوقت، فلترة الفئة وحدها تكفي (موجودة أصلاً عبر التنقل، ليست ميزة إضافية).
- التحقق (Validation) في فورم التواصل — تحقق بسيط جداً (حقل غير فارغ) بدل تحقق تنسيق رقم هاتف معقّد.
- Loading states — Spinner افتراضي بسيط بدل أي رسوم متحركة مخصصة.

### CUT FIRST (إن ضاق الوقت فعلاً)
- البحث النصي بالكامل.
- أي حركة/Animation انتقالية بين الشاشات (الاكتفاء بانتقال `go_router` الافتراضي).
- صفحة/قسم "كيف نعمل" (Should Have في Product Spec، وليست Must).

### DO NOT BUILD (خارج النطاق كلياً — قرار منتج، ليس قرار وقت)
- Vendor Dashboard/Login فعلي.
- نظام Reviews/Ratings.
- أي ميزة اجتماعية.
- دفع إلكتروني فعلي أو تقويم توفر حي.
- حجب رابط/مصدر المزوّد.

---

## 21. TECHNICAL RISKS

| Risk | Impact | Probability | Mitigation |
|---|---|---|---|
| Free-tier Supabase يتطلب إعداد RLS بدقة، وإعداد خاطئ قد يمنع الإرسال أو يفتح القراءة للجميع خطأً | متوسط-عالٍ (يكسر Contact Flow أو يسرّب بيانات المستخدمين) | متوسطة | اختبار Insert فعلي من اليوم 1 مباشرة (وليس اليوم 3)؛ جاهزية Google Form كـFallback فوري إن تعطّل الإعداد |
| صور المزودين (خصوصاً إن روابط خارجية من Instagram) قد تُحذف/تتغير صلاحياتها فجأة | عالٍ إن حدث أثناء العرض المباشر تحديداً | منخفضة-متوسطة | التوصية بـlocal assets للـDemo تحديداً (القسم 13) — يُلغي هذه المخاطرة كلياً |
| جمع/تحويل بيانات الـ30-60 مزوّد الحقيقيين يتأخر (يدوي، يعتمد على عضو آخر من الفريق) | عالٍ جداً — كل شاشة تعتمد على `providers.json` | متوسطة-عالية | يبدأ من الساعة صفر بالتوازي مع الكود (القسم 17)؛ استخدام 3-5 مزودين وهميين مؤقتاً لتطوير الواجهة دون انتظار البيانات الحقيقية الكاملة |
| Backend/API failure أثناء العرض المباشر أمام اللجنة تحديداً (انقطاع إنترنت في القاعة) | عالٍ (يفشل Contact Flow حصرياً، وليس التصفح إن كانت الصور local) | متوسطة | رسالة خطأ صادقة وواضحة عند فشل الإرسال (القسم 10) بدل تجميد/كراش؛ اختبار الشبكة الفعلية في مكان العرض قبل الوقت المحدد |
| ضيق الوقت يدفع لدمج طبقات (مثلاً استدعاء Supabase مباشرة من الشاشة) | منخفض التأثير الآن، لكنه يصعّب أي تعديل لاحق سريع | متوسطة | الالتزام بالـRepository pattern حتى تحت ضغط الوقت — الفرق في الوقت بسيط جداً مقابل الفائدة |
| تعارضات Dependencies بين الحزم (Riverpod/go_router/Supabase versions) | متوسط | منخفضة-متوسطة | تثبيت (`pin`) إصدارات الحزم من اليوم 1 وعدم تحديثها العشوائي منتصف الهاكاثون |

---

# FINAL TECHNICAL DECISION

**Frontend:** Flutter (stable) + Dart
**Architecture:** MVVM مبسّط + Repository، بدون Domain layer منفصلة
**State Management:** Riverpod
**Navigation:** go_router
**Backend:** لا Backend كامل — Supabase (جدول واحد، بدون Auth) لطلبات التواصل فقط، بديل احتياطي Google Form
**Database:** Static JSON محلي (`assets/data/providers.json`) لعرض المزودين + جدول Supabase واحد للكتابة
**Storage:** Local image assets (موصى به للعرض المباشر) مع `cached_network_image` جاهزة كخيار بديل
**Networking:** `http`/`supabase_flutter` — فقط لإرسال طلب التواصل، لا استخدام آخر للشبكة
**Data Strategy:** بيانات المزودين تُجمَّع يدوياً (Instagram → Sheet → JSON → rebuild) — لا تحديث لحظي، مطابق لقرار المنتج بأن البيانات تُدار يدوياً من الفريق
**Screens:** 5 شاشات فقط (Home, Category, Provider Details, Contact Request, Contact Success)
**Testing:** Unit (Repository/parsing/filtering) + Widget (Card, Empty State, Form validation) + Integration (الـFlow الكامل من التصفح للإرسال الناجح) — أولوية للـIntegration test لأنه يحمي الـDemo مباشرة
**Estimated MVP Complexity:** منخفضة-متوسطة — مناسبة تماماً لـ3 أيام و$0 وفريق من 1-3 مطورين
**3-Day Critical Path:** جمع/تحويل بيانات المزودين الحقيقية (يبدأ فوراً بالتوازي) → `ProvidersRepository` (يوم 1) → شاشات التصفح/التفاصيل (يوم 2) → Contact Flow + اختبار الـFlow الكامل (يوم 3)

---

## HANDOFF TO CLAUDE #4 — Flutter Developer

1. **Project setup**
   - `flutter create sawa` (أو اسم المستودع الحالي إن كان موجوداً بالفعل على GitHub).
   - تفعيل `flutter_lints`/`analysis_options.yaml` قياسي منذ البداية.

2. **Dependencies (`pubspec.yaml`)**
   ```yaml
   dependencies:
     flutter_riverpod: ^latest
     go_router: ^latest
     supabase_flutter: ^latest      # أو http فقط إن اختير مسار Google Form
     cached_network_image: ^latest  # إن استُخدمت روابط صور خارجية
   dev_dependencies:
     flutter_test: sdk
     mockito: ^latest                # أو mocktail — للـRepository mocks في الاختبارات
   ```
   *(ثبّت أرقام إصدارات فعلية عند الإعداد الحقيقي، لا تترك `^latest` حرفياً في الملف.)*

3. **Folder structure:** طابِق القسم 4 حرفياً منذ أول commit.

4. **Models:** ابدأ بـ`Provider` و`ContactRequest` (القسم 6) — بدون أي حقل إضافي غير مذكور هناك.

5. **Data source:**
   - ضع `providers.json` (حتى لو ببيانات وهمية مؤقتة أولاً) في `assets/data/` وسجّله في `pubspec.yaml` تحت `flutter: assets:`.
   - `ProvidersRepository.getAll()` يقرأ الملف عبر `rootBundle.loadString()` ويحوّله لقائمة `Provider`.

6. **Navigation:** أنشئ `app_router.dart` بكل المسارات الخمس فوراً في اليوم 1، حتى لو الشاشات مبدئياً `Placeholder()`.

7. **State management:** أنشئ الـProviders/Notifiers الأساسية أولاً (`providersListProvider`, `contactRequestNotifierProvider`) قبل بناء أي Widget يعتمد عليها.

8. **Screens:** ابنِها بالترتيب من القسم 5، بنفس ترتيب الـExecution Plan (القسم 17).

9. **Components:** ابنِ `AppCard`/`AppButton`/`LoadingView`/`ErrorView`/`EmptyStateView` في `core/widgets/` **قبل** استخدامها في أي Feature، بحيث لا تتكرر أنماط UI يدوياً في كل شاشة.

10. **API/Database integration:** لا تستدعِ Supabase مباشرة من أي Widget — فقط عبر `ContactRequestRepository`. اختبر الـinsert الفعلي (حتى ببيانات وهمية) في أول ساعتين من اليوم 1 للتأكد من صحة RLS policy مبكراً جداً، وليس في اليوم الأخير.

11. **Testing:** التزم بالحد الأدنى من القسم 16 فقط — لا تتوسع أكثر من ذلك تحت أي إغراء لضيق الوقت. Integration test للـFlow الكامل **إلزامي** قبل يوم العرض.

12. **Build/run checklist (قبل العرض مباشرة):**
    - [ ] `flutter analyze` بدون أخطاء.
    - [ ] `flutter test` كل الاختبارات تمر.
    - [ ] تشغيل فعلي على الجهاز/المحاكي المستخدم في العرض تحديداً (ليس فقط جهاز المطوّر).
    - [ ] تجربة الـFlow الكامل مرتين متتاليتين بدون كراش.
    - [ ] تأكيد وصول طلب تواصل تجريبي فعلياً إلى Supabase Table Editor/Google Sheet أمام أحد أعضاء الفريق.
    - [ ] فصل الإنترنت والتأكد أن التصفح (Home → Category → Details) يعمل كاملاً بدونه (إن كانت الصور local assets).
