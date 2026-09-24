# SAWA v2 — Locked Product Decisions

**Status:** Locked · **Date:** 2026-09-24 · **Supersedes:** the MVP-only clauses of
`SAWA_FINAL_MASTER_SPEC.md` listed at the bottom.

SAWA is now a **Premium Event & Wedding Marketplace / Planning Platform for Iraq**
with two sides — **Customer** (plans an event, finds providers) and **Provider**
(runs a business profile, services and requests). The v1 guest browse →
contact flow remains part of the product, but is no longer the whole product.

## 1. Guests are never blocked
- Browsing and **sending a contact request** work without an account.
- A guest provides the minimum needed (name + phone), receives a reference
  code, and can never read requests back.
- A signed-in customer's request is linked to `customer_id` and appears in
  *My Requests* with its status.
- Rate limiting and anti-spam are enforced server-side from day one.

## 2. Customer → SAWA → Provider
- Every request reaches the **SAWA team first**.
- Listings sourced by SAWA (e.g. the provider PDFs) are `source = pdf`,
  `user_id = null`. We never assume the business owner has an account.
- A self-registered provider sees a request only after SAWA forwards it.
- The database allows a future claim/ownership workflow; it is **not** built now.

## 3. Phone privacy
- Provider phone numbers are not shown to customers by default (stored in
  `provider_private`). Contact happens through *طلب تواصل*.
- Instagram / external links that are public business information may be shown.
- Customer phone numbers are never public.

## 4. Data quality over quantity
- A provider is added only when its data is usable and its source is clear.
- Every field carries a provenance status: `verified | source_only | unverified | missing`.
  Nothing is guessed — prices, Instagram handles, locations, capacity,
  services and images included.
- The existing 15 providers are the base. Known corrections:
  Fayrouz price → `missing`; Ward Baghdad Instagram → `unverified` (two handles
  in source); Tabarek Instagram → `unverified` (not labelled as Instagram);
  Ritaj / Asawer prices → time-bound **offers/packages**, not base prices.
- The 4 florists move to **Flowers**. **Decoration** stays an empty, honest category.

## 5. Images
- Use images extracted from the source PDFs only when they are genuine
  provider imagery: no phone numbers, no catalog text, no Instagram/PDF
  screenshots, acceptable quality.
- Otherwise use a branded category placeholder. Never invent images or pull
  random images from the internet.

## 6. Design system first
- The SAWA Premium Design System (tokens, typography, components, states,
  image treatment) is established at the start of Phase 2/3. Phase 6 is
  refinement and responsive polish, not a rebuild.
- Direction: **Luxury Iraqi Event Platform** — premium, elegant, feminine but
  mature, modern, warm, confident. Palette: Ivory, Warm White, Charcoal,
  Deep Burgundy/Wine (hierarchy + primary CTAs only), Champagne, Muted Gold,
  soft neutrals. Not all-burgundy, no childish pink, no excessive gold, no
  generic wedding template, no Instagram clone.

## 7. Honesty rules
- No fake data, reviews, analytics, providers or success states.
- Dashboard numbers come from real rows; otherwise show
  *لا توجد بيانات كافية حالياً*.
- The planner uses **explainable rule-based matching** (category, location,
  budget, capacity, service compatibility). It is never called AI.

## 8. Not now
Payments, subscriptions, reviews, chat, advanced AI, complex admin dashboard,
full claim workflow — unless required for the architecture to function.

## 9. Security
Enforced in Supabase (RLS + guard triggers + RPCs), never by client-side role
checks. See `supabase/README.md`. "Confirm email" is off during development/QA
only and is reviewed separately before production.

---

### Superseded clauses of `SAWA_FINAL_MASTER_SPEC.md`
- T3 / §"Supabase single table, no auth" and §26 "No authentication system built" → replaced by Supabase Auth with customer/provider/admin roles.
- §"Vendor self-service login" listed as future → now in scope (Provider portal).
- Provider data as a static JSON asset → moves to Supabase (`providers` + related tables); `provider-data/` PDFs remain **source material only**.
- The three-category limit (قاعات، مصورين، ديكور) → extensible `categories` table.
