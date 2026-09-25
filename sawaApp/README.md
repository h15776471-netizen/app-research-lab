# SAWA — Flutter app

Premium Iraqi event & wedding platform (Baghdad first). Flutter web · Riverpod ·
go_router · Supabase (Auth + Postgres RLS + Storage).

## Run

```powershell
flutter pub get
# Offline catalog mode (browse only — writes show an honest "not connected" state)
flutter run -d chrome
# Connected to Supabase (publishable key only — never a secret/service key)
flutter run -d chrome --dart-define=SUPABASE_URL=https://<id>.supabase.co --dart-define=SUPABASE_ANON_KEY=<publishable key>
```

Setting up a new Supabase project: [`../docs/NEW_SUPABASE_SETUP.md`](../docs/NEW_SUPABASE_SETUP.md).

## Check

```powershell
flutter analyze        # 0 issues
flutter test           # unit + widget + offline end-to-end smoke tests
flutter build web --release
```

## Structure

```
lib/
├── core/        theme (tokens), router (+ pure redirect rules), auth state,
│                utils (formatters, error mapping), shared widgets
├── data/
│   ├── models/        rows of the Supabase schema (catalog + account models)
│   ├── repositories/  catalog (Supabase | bundled catalog.json), auth,
│   │                  requests (RPCs), provider portal
│   └── data_providers.dart   Riverpod wiring
└── features/
    ├── auth/              splash, welcome, login, sign-up (role), reset
    ├── customer/          home, planner (rule-based engine), my requests, profile
    ├── providers_list/    explore + category (search / filters), provider card
    ├── provider_details/  gallery, packages & offers, services, provenance
    ├── contact_request/   guest-friendly request → reference code
    └── provider/          portal: dashboard (real stats), onboarding,
                           services & packages, forwarded requests, gallery
```

## Data rules (enforced in code and tests)

- Provider data comes from `assets/data/catalog.json`, generated from
  `provider-data/catalog/providers.v2.json` — never edited by hand.
- Unknown data shows «غير متوفر», ambiguous data «غير مؤكد». Nothing is guessed.
- Offers (`is_offer`) are labelled «عرض» and never shown as the base price.
- Photos are extracted from the source catalogs; no catalog page renders, no
  Instagram screenshots. Providers without a genuine photo show a branded placeholder.
- Provider phone numbers never ship to the client (`provider_private`, owner + admin only).
- Permissions are enforced by Postgres RLS / triggers; role checks in the app only shape navigation.
