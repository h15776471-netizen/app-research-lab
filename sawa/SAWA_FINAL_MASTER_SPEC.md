# SAWA — FINAL MASTER SPECIFICATION & SYSTEM AUDIT

> **⚠️ Partially superseded (2026-09-24):** SAWA v2 is a two-sided marketplace with Supabase Auth.
> Where this document conflicts with [`SAWA_V2_DECISIONS.md`](SAWA_V2_DECISIONS.md) (auth, provider
> portal, data source, categories), **the v2 decisions win**.
**Role:** Master Reviewer & System Integrator
**Status:** Pre-implementation review, complete
**Scope:** Full review of Research (Claude #1), Product Spec (Claude #2), Technical Architecture (Claude #3), Design System (Claude Design), synthesized into one Source of Truth for the Flutter Developer.

Legend used throughout: **[FACT]** verifiable from a source file · **[EVIDENCE]** supports a claim · **[ASSUMPTION]** unverified premise · **[RECOMMENDATION]** this review's suggestion · **[DECISION]** what is now locked · **[CONFLICT]** contradiction between sources · **[GAP]** required but not implemented · **[UNNECESSARY]** implemented but not required · **[UNKNOWN]** cannot be determined from available material · **[OPEN DECISION]** needs a human call · **[COST RISK]** possible unexpected spend.

---

## PHASE 0 — FULL PROJECT INVENTORY

| File / Artifact | Source | Role | Status |
|---|---|---|---|
| `wedding-event-platforms-forensic-research.md` | Claude #1 | Research | **[CURRENT]** — six-platform forensic teardown, explicit evidence tags, ends with an Iraq-lens handoff |
| `sawa-product-specification.md` | Claude #2 | Product | **[CURRENT]** — final for hackathon MVP, locked Product Decisions §"Product Decisions لا يجب أن يغيّرها Technical Architect" |
| `sawa-technical-architecture.md` | Claude #3 | Technical | **[CURRENT]** — explicitly built "on top of" the Product Spec, ends with a direct handoff to Claude #4 |
| `sawa-design-system-ux-handoff.md` | Design Lead | Design | **[CURRENT]** — explicitly built on top of both Product Spec and Technical Architecture, ends with a direct handoff to Claude #4 |
| `README.md` | repo | Other | **[CURRENT]**, empty placeholder (`app-research-lab`) — no content to reconcile |

No duplicate or outdated files were found — this is a clean, single-pass chain (Research → Product → Technical → Design), each layer citing the one before it as source of truth. **No file-level conflicts** exist; conflicts found below are *content*-level, between what two aligned documents each assume.

---

## PHASE 1 — REQUIREMENTS MASTER LIST (condensed)

### Product Requirements
| ID | Requirement | Source | Priority | Status |
|---|---|---|---|---|
| P1 | 3 categories: halls, photographers, decor — Baghdad only | Product Spec | MUST | Implemented (Technical §5, Design §12) |
| P2 | 10–20 real providers per category | Product Spec | MUST | **[GAP — data collection, see Phase 9]** |
| P3 | Organized provider card: photos, basic info, price range if available | Product Spec | MUST | Implemented (Design §16) |
| P4 | Basic search/filter by category | Product Spec | MUST | Implemented via navigation (Home→Category); free-text search is **SHOULD** |
| P5 | Contact/booking request routed through sawa | Product Spec | MUST | Implemented (Technical §10, Design §18) |
| P6 | Original source link (provider's Instagram) always visible, never hidden | Product Spec | MUST | Implemented (Details screen only — see Phase 11 gap discussion) |
| P7 | Text layer: "تمت مراجعته من فريق sawa" | Product Spec | MUST | Implemented verbatim (Card + Details) |
| P8 | Honest follow-up message: "نتابع طلبك ونساعدك بالتواصل مع المزوّد" | Product Spec | MUST | Implemented verbatim (Success screen) |
| P9 | "How we work" section | Product Spec | SHOULD | Cut-list candidate in both Technical and Design docs — consistent |
| P10 | Non-functional vendor-dashboard mockup for pitch deck only | Product Spec | SHOULD | Not a build item — presentation asset, correctly excluded from app scope |

### User Requirements
| ID | Requirement | Source | Priority |
|---|---|---|---|
| U1 | Find a category-matched provider quickly, without Instagram-style chaos | Product Spec (Core Problem) | MUST |
| U2 | See price range before contacting, when available | Product Spec | MUST |
| U3 | Verify the provider independently via original Instagram | Product Spec | MUST |
| U4 | Submit a contact request without exposing a provider's direct number | Product Spec | MUST |
| U5 | Get an honest, non-inflated confirmation, not a fake guarantee | Product Spec | MUST |

### Business Requirements
| ID | Requirement | Source | Priority |
|---|---|---|---|
| B1 | No claim of "verified" (موثّق) anywhere in UI | Product Spec | MUST (non-negotiable) |
| B2 | No response-time promise (hours/half-day) anywhere in UI | Product Spec | MUST (non-negotiable) |
| B3 | Providers are not users in this version; data is team-managed | Product Spec | MUST |
| B4 | No real payment gateway, no live availability calendar | Product Spec | OUT OF SCOPE |
| B5 | Personal Instagram channel (1,700 followers) is the launch channel | Product Spec | Context, not a build requirement |

### Technical Requirements
| ID | Requirement | Source | Priority |
|---|---|---|---|
| T1 | Flutter/Dart, Riverpod, go_router, MVVM+Repository, no Domain layer | Technical Arch | MUST |
| T2 | Provider data: static local JSON asset (read-only) | Technical Arch | MUST |
| T3 | Contact requests: Supabase single table, no auth, insert-only RLS | Technical Arch | MUST, fallback Google Form |
| T4 | Images: local assets recommended for demo safety | Technical Arch | MUST for demo; `cached_network_image` kept as pubspec dependency for future swap |
| T5 | 5 screens only, linear navigation | Technical Arch | MUST |
| T6 | `.env`/`--dart-define` for Supabase anon key, not hardcoded | Technical Arch | MUST |

### Design Requirements
| ID | Requirement | Source | Priority |
|---|---|---|---|
| D1 | Direction A ("Organized Notebook") — flat, border-based, warm/terracotta | Design | **[OPEN DECISION — see Phase 6]** |
| D2 | Cairo font (Google Fonts), RTL-first | Design | MUST |
| D3 | No shadows except optional 1dp on primary button | Design | MUST |
| D4 | 4:3 image ratio everywhere | Design | MUST |
| D5 | Sticky bottom "طلب تواصل" button on Details screen | Design | MUST — explicitly called "أهم قرار UX في كامل التطبيق" |
| D6 | No fake trust decoration (no stars, no fake counters, no gold "Verified ✓" badge) | Design | MUST (direct implementation of B1) |

### Data Requirements
| ID | Requirement | Source | Priority |
|---|---|---|---|
| DA1 | `Provider` model: id, name, category, images[], priceRangeText?, shortDescription?, instagramUrl, city, reviewedBySawa | Technical Arch §6 | MUST |
| DA2 | `ContactRequest` model: providerId, userName, userContact, note?, createdAt | Technical Arch §6 | MUST |
| DA3 | Optional fields hidden silently when absent, never "غير متوفر" | Technical Arch + Design | MUST |
| DA4 | Data pipeline: Instagram → Sheet → CSV → JSON → asset rebuild | Technical Arch §7 | MUST |

### MVP / Competition / Demo Requirements
| ID | Requirement | Source | Priority |
|---|---|---|---|
| M1 | Full working flow, all 3 categories, zero crashes in front of judges | Product Spec (Success Criteria) | MUST |
| M2 | App must browse fully offline (if images are local assets) | Technical Arch §17, §21 | MUST |
| M3 | Team must be able to justify: why not Instagram, why not "قاعات/مناسبات", who pays, roadmap | Product Spec (Success Criteria) | MUST (pitch, not code) |

### Constraints
- $0 budget, 3 days, Flutter/Dart, design not yet finalized when Technical Architecture was written (resolved by Design doc) — **[FACT]**, stated identically across all three downstream docs.

### Non-Functional Requirements
- Performance: `ListView.builder`, `const` widgets, Riverpod `select` — **[FACT, Technical §15]**.
- Accessibility: 48×48 touch targets, ≥4.5:1 text contrast, RTL, no color-only error state — **[FACT, Design §22]**.
- Security: RLS insert-only, anon key in `.env`, no PII readable by client — **[FACT, Technical §14]**.

---

## PHASE 2 — SOURCE OF TRUTH MAPPING (sample of the most consequential decisions)

| Decision | Origin | Current status | Conflicting decision? | Final recommendation |
|---|---|---|---|---|
| 5 screens, linear flow | Product Spec journey (6 prose steps) → Technical Arch (5 named screens) → Design (5 screen specs) | Aligned | No — the Product Spec's 6-step *prose* journey and the 5 *screens* are not the same unit (step "المزودون يتابع الطلب يدوياً" has no screen because it's backstage), so this is **not** a conflict, just different granularity. | Keep 5 screens as canonical. |
| Vendor phone number never shown | Product Spec Decision #3 | Technical Arch (no `providerPhone` field exists) + Design (card has no contact button) | No conflict | Locked |
| Image storage: local assets vs URLs | Technical Arch §2/§13 leaves it **[OPEN DECISION]**, recommends local for demo | Design §11 also defers to Technical Arch's recommendation and reinforces "local for demo" | Not a conflict — both independently converge on the same recommendation | **[DECISION]** Local assets for the hackathon demo (see Phase 8) |
| Visual direction (A vs B vs C) | Design doc itself flags this as **[UX ISSUE]**, recommends A but says the A/B choice is partly a pitch-strategy call outside UX authority alone | Not contradicted elsewhere | N/A | Carried forward as **[OPEN DECISION]** below — this review does not have the standing to override a flagged business/pitch trade-off with no new input from the team |
| "No direct contact number required to send request" (Product Spec journey line) vs. `userContact` marked **Required** in Technical Arch's data model and Design's form table | Product Spec §Core User Journey step 4 ("لا رقم تواصل مباشر مطلوب لإرسال الطلب") | Technical Arch §6 `ContactRequest.userContact` = Required; Design §18 marks "وسيلة التواصل" = "نعم" (required) | **[CONFLICT — see Conflict Register C1]** | Resolved as an ambiguity, not a real contradiction — see C1 |

---

## PHASE 3 — FULL SYSTEM MAP

```
Research (6-platform forensic teardown)
   ↓ feeds "AVOID" list (no app-wall CTA, no vendor-adversarial lock-in, no overloaded mega-menus)
Product Problem (Instagram chaos + dead local apps in Baghdad wedding market)
   ↓
Product Philosophy ("documented quality > unverified quantity"; "honesty in the promise > first impression")
   ↓ directly forbids: "موثّق", time-bound reply promises, hiding the Instagram source
Value Proposition (curated, team-reviewed provider list + a real follow-up on contact requests)
   ↓
MVP Scope (3 categories, 10–20 providers each, Baghdad only, no vendor login, no payments)
   ↓
User Journey (category → browse → details → optional Instagram check → contact request → honest confirmation)
   ↓
UX (5-screen linear IA, sticky CTA on Details, no Drawer/BottomNav)
   ↓
Design System (Direction A: warm/terracotta, border-not-shadow, Cairo, RTL)
   ↓
Technical Architecture (Flutter/Riverpod/go_router/MVVM+Repository, static JSON + one Supabase table)
   ↓
Data Model (Provider, ContactRequest — fields traced to exactly what the UI shows)
   ↓
Implementation (Claude #4 — not yet started)
   ↓
Testing (Unit: repo/parsing/filter; Widget: card/empty/form; Integration: full flow — explicitly prioritized)
   ↓
Demo (judges see the 5-screen flow live; offline browsing + a real Supabase insert are the two things that must survive)
```

**Dependency chain if a decision changes:**
- If **"no موثّق" (B1)** were reversed → cascades through Product Philosophy, the `reviewedBySawa` field's UI treatment, the Design badge component, and the pitch narrative (Success Criteria M3). This is the single most load-bearing decision in the whole project.
- If **image storage** moved from local assets to URLs → touches Technical §2/§13/§21 (removes the offline-safety mitigation), Design §11 (placeholder logic no longer "rare"), and the Demo Safety Plan (re-introduces a network-failure risk class).
- If **screen count** changed → touches Technical §4 folder structure, §17 execution plan, Design §12–19 screen specs, and the Requirements Traceability Matrix wholesale. High blast radius — this is why it should stay locked.

---

## PHASE 4 — CRITICAL AUDIT

### Product
- The problem statement is evidence-based, not assumed: it cites the team's own direct experience with Instagram response times and names two specific failed local incumbents ("قاعات", "مناسبات") — **[EVIDENCE]**, stronger footing than most hackathon pitches.
- The value proposition is honest about what it *cannot* yet deliver (no real verification system, no SLA) — this is a genuine differentiator versus the Research doc's own finding that WeddingPro-style vendor lock-in creates "documented friction" (Research §AVOID). Good use of Research→Product traceability.
- **Weakness:** the MVP's core trust claim ("تمت مراجعة بياناته من فريق sawa") is not defined operationally anywhere — *what counts as "reviewed"*? Even a one-line internal checklist (e.g., "team confirmed the Instagram account is active and has ≥N recent posts") would make the badge defensible under judge questioning. This is a **[GAP]** in Product, not Design or Technical — flagging for Product owner, not fixing here (would be scope creep to invent one).

### Business
- Monetization is explicitly **[OUT OF SCOPE]** for the MVP — no revenue model is specified beyond the implied future "verification tiers" roadmap item. This is appropriate for a 3-day hackathon MVP and should not be treated as a gap; Research shows every studied platform (Group A) monetizes vendor-side, which is a viable future direction already implicitly aligned with, but this review will not invent a business model that no source document commits to.
- Provider acquisition is fully manual (team-sourced from Instagram) — consistent with Product Spec §"Providers not users", and correctly reflected end-to-end in Technical (§7 pipeline) and Design (no vendor-facing screens at all).

### UX
- The journey has **no dead end**: every screen has exactly one primary action and a way back (Design §12, §19 "كل شاشة قرار واحد فقط"). This matches the Research doc's own critique of The Knot's single-CTA-wall pattern — sawa's version differs constructively by keeping the browsing screens fully navigable rather than gating everything behind one action.
- **Minor UX risk:** the Instagram link lives only on the Details screen, not the card (Design §16, point 6: "لا زر Instagram... على البطاقة نفسها"). Product Decision #3 only requires the link not be hidden — it does not require card-level placement — so this is compliant, not a gap. Documented for completeness in Phase 11.

### UI / Design
- Direction A is the only one of the three that is simultaneously (a) fastest to implement in Flutter, (b) furthest from the "Western wedding catalog" stereotype the brief explicitly rules out, and (c) most literal translation of "no visual promise bigger than the truth." The recommendation is well-argued, not just asserted — **[EVIDENCE]** present in the Design doc itself.
- **Real accessibility flag:** the Secondary color `#D9A05B` (used for the "reviewed" badge icon) against a white/cream surface produces roughly ~2:1 contrast, below the 3:1 WCAG minimum for meaningful graphical UI elements. Because this badge is exactly the element carrying the project's core trust claim, it should not be allowed to be the *least* legible element on the card. **[NEEDS FIX]** — swap the icon fill to Text Secondary (`#6B5F58`, already confirmed ≥4.5:1) or Primary, and reserve `#D9A05B` strictly for a thin border/fill accent, not for any element meant to be read at a glance. This does not require new design tokens — it's a component-level correction within Design §16/§20.

### Technical
- The layered but Domain-free architecture is justified against actual scope (≤6 screens) rather than applied as boilerplate ritual — good calibration, matches Technical Arch's own stated principle ("الأبسط الذي يعمل فعلياً" over "الأفضل نظرياً").
- The Repository layer is kept even though it's "unnecessary" for 3 days, specifically to make the post-hackathon JSON→API swap cheap — this is the one deliberate piece of complexity the doc allows itself, and it justifies it by naming the exact future beneficiary (Roadmap). Sound trade-off.
- **[COST RISK] flagged and correctly mitigated:** Supabase free tier has no card requirement and the fallback (Google Form) has zero setup risk. No paid dependency exists anywhere in the stack (see Phase 8 table).

### Data
- Schema is minimal and directly UI-driven — every field in `Provider` maps to something visibly rendered (Phase 13 traces this explicitly; no orphan fields found).
- **[GAP]** noted already in Product Requirements: the actual 30–60 real providers do not yet exist as of these documents — this is the single highest-probability point of hackathon failure (see Phase 9 Critical Path and Phase 15 Demo Safety Plan).

### Demo
- The plan already treats "real Supabase insert visible to a team member" and "offline browsing works" as explicit Definition-of-Done items (Technical §17 Day 3, §21 checklist) — this is unusually disciplined for a hackathon spec and should not be watered down under time pressure.

---

## PHASE 5 — CONFLICT REGISTER

### C1 — "No contact number required" vs. `userContact` marked Required
- **Decision A:** Product Spec, Core User Journey step 4: *"يرسل طلب تواصل/حجز عبر sawa (لا رقم تواصل مباشر مطلوب لإرسال الطلب)."*
- **Decision B:** Technical Arch §6, `ContactRequest.userContact` = **Required**; Design §18 form table marks "وسيلة التواصل" = "نعم" (required).
- **Why they conflict:** read literally, A says a contact number is *not* required to submit the request; B requires the user's phone number as a mandatory field.
- **Impact:** Low in practice, but a literal-minded developer could build a submit button that never asks for a phone number, breaking the entire point of the follow-up promise ("نتابع طلبك ونساعدك بالتواصل").
- **Which layer owns this:** Product (the sentence is ambiguous, not the two downstream docs).
- **Options:** (1) Interpret A as referring only to the *provider's* number (which is never shown/required, per locked Product Decision #3) — user's own number is a separate, obviously-required field. (2) Interpret A literally and make `userContact` optional.
- **Recommended resolution:** Option 1. Every other Product Decision, plus the entire premise of "نتابع طلبك," depends on sawa having a way to reach the user. Option 2 would make the core value proposition non-functional.
- **What must change after resolution:** Nothing in Technical or Design — they already implement Option 1's outcome. **[RECOMMENDATION]:** the Product Spec sentence should be reworded in the next revision to "لا رقم تواصل مباشر **للمزوّد** مطلوب لإرسال الطلب" to remove the ambiguity for future readers — flagged, not silently rewritten here since this review does not have authority to edit a locked Product Decision.

### C2 — Visual direction ownership
- **Decision A:** Design doc recommends Direction A but explicitly labels the A-vs-B choice a **[UX ISSUE]** partly outside UX's own authority (pitch-strategy dependent: warmth vs. market-ready polish).
- **Decision B:** No other document takes a position.
- **Why they conflict:** it isn't a conflict between two decisions — it's an acknowledged single open decision that the Design doc correctly declined to unilaterally resolve.
- **Impact:** Low technical impact (both directions are equally cheap to implement per Technical §12); real impact is only on judge perception.
- **Which layer owns this:** Product/Business (pitch strategy), not Design or Technical.
- **Recommended resolution:** Proceed with Direction A as default (already the working default in the Design doc's tokens, Phase 21 below), since it is reversible without touching any screen file (Design §26 confirms zero Design-Tech conflicts and Technical §12 confirms token-only swap). **Carried forward as [OPEN DECISION D1]** for the team to confirm before Day 1 ends, not resolved unilaterally by this review.

### C3 — Free-text search: Must or Should?
- **Decision A:** Product Spec Must Have table lists "بحث/فلترة أساسية (حسب الفئة)" as **Must**.
- **Decision B:** Technical Arch §9 and Design §27 both treat the **free-text search field** as **Should Have**, first item on both "cut first" lists.
- **Why they conflict:** surface-level wording looks contradictory ("Must" vs "cut first").
- **Impact:** None once traced carefully — Product Spec's Must item is *category filtering*, which is delivered structurally through Home→Category navigation, not through a text search box. The text search field is an *additional* convenience layer both downstream docs correctly scope as optional.
- **Recommended resolution:** Not a real conflict — terminology overlap only. **[RECOMMENDATION]:** keep as-is; no rework needed.

No other conflicts were found between Product, Technical, and Design across the MUST-tier requirements. This is a well-aligned chain — the three-conflict count is low precisely because each downstream document explicitly cites and defers to the one before it rather than re-deciding things independently.

---

## PHASE 6 — CRITIQUE OF THE TWO HIGHEST-STAKES DECISIONS

### Decision: Local image assets (not remote URLs) for the hackathon build
- **Why:** eliminates all network dependency for browsing during the live demo.
- **[EVIDENCE]:** Technical §21 names "internet outage in the room" explicitly as a risk; Design §11 independently reaches the same conclusion.
- **Weaknesses:** any image update requires a full app rebuild; app binary size grows with 30–60 photos; if real provider photos arrive late (Phase 9's #1 risk), swapping them in is a rebuild each time, not a hot content update.
- **Hidden assumption:** that provider photos will be sourced, cropped to 4:3, and compressed *before* the final rebuild, with enough buffer before demo day.
- **Failure scenario:** if photos are still trickling in on Day 3 evening, the team either demos with placeholder/mismatched images or does a last-minute rebuild under time pressure — a self-inflicted demo risk.
- **Alternative:** remote URLs with `cached_network_image`, prefetched and warmed before the demo (so the images are already in the device cache and technically "offline" for the duration of the demo even though sourced remotely).
- **Alternative's weakness:** cache-warming has to be done manually right before walking into the room, is easy to forget, and Instagram-hosted image URLs can expire or be rate-limited (Technical §21 already flags this for the URL option generally).
- **Comparison:** Local wins decisively on demo reliability (the single highest-priority axis per Phase 15) even though it loses on update flexibility — flexibility doesn't matter for a one-time hackathon demo.
- **[DECISION]:** Local assets, confirmed. No change from the existing recommendation.

### Decision: Supabase single table, no auth, for contact requests
- **Why:** gives the team a live, queryable table (Table Editor) with effectively zero setup cost and no card requirement.
- **[EVIDENCE]:** Technical §8 compares three real options (Supabase / Google Form / local-only) and correctly eliminates local-only as contradicting the core value prop ("نتابع طلبك").
- **Weaknesses:** RLS misconfiguration is a real, named risk (Technical §21) — an insert-open + select-open table by mistake would leak user names and phone numbers.
- **Hidden assumption:** someone on the team actually configures and *tests* the RLS policy on Day 1, not Day 3.
- **Failure scenario:** RLS policy is broader than intended, is only noticed during Q&A when a judge asks "who can read this data?" — a credibility risk beyond a technical one, since the entire pitch rests on "صدق الوعد."
- **Alternative:** Google Form as the *primary* channel instead of fallback — zero RLS risk since Google manages access control, ~10 minutes to set up.
- **Alternative's weakness:** breaks the in-app design system (user leaves the sawa UI, undermining the "منظّم" brand personality that is itself a stated differentiator), and per Technical §8 is explicitly weaker on UX grounds.
- **Comparison:** Supabase wins on brand/UX consistency; Google Form wins on security-by-default and setup speed. Given RLS testing is already scheduled for "first two hours of Day 1" (Technical Handoff §10) rather than Day 3, the risk is front-loaded and mitigated — the original recommendation still holds.
- **[DECISION]:** Supabase as primary, Google Form as fallback — confirmed, contingent on the RLS test happening on Day 1 as already specified. This is flagged in the Demo Safety Plan below as a Day-1 gate, not merely a nice-to-have.

**Stopping condition for further second-order critique (Phase 7):** both decisions above stabilize after one round of alternative comparison — no further alternative meaningfully improves demo-reliability or trust-consistency beyond what's already specified, given the $0/3-day constraint. Continuing to iterate (e.g., a self-hosted Postgres, a custom minimal backend) would only add setup risk without a corresponding benefit at this scale. Stopping here.

---

## PHASE 8 — ZERO-BUDGET AUDIT

| Item | Cost | Free tier | Setup complexity | [COST RISK]? | Alternative if it breaks |
|---|---|---|---|---|---|
| Supabase (1 table, no auth) | $0 | Yes, no card | Low-medium | Low — free tier request limits are far above hackathon traffic | Google Form |
| Google Form (fallback) | $0 | N/A (free product) | Very low | None | — |
| Static JSON asset | $0 | N/A | Low | None | — |
| Local image assets | $0 | N/A | Low | None (only risk is app binary size, not money) | — |
| `imgbb.com` (if URLs chosen instead) | $0 | Sufficient for 30–60 images | Low | Low — free API, no card, but third-party uptime is out of team's control | Local assets |
| Google Fonts (Cairo, via `google_fonts` package) | $0 | Unlimited for this use | Very low | None | — |
| Material Icons | $0 | Bundled with Flutter | None | None | — |
| Phosphor/Lucide Icons (optional) | $0 | Open-source packages | Low | None | Material Icons (default) |
| `cached_network_image` package | $0 | Open-source | Low | None | — |
| go_router, Riverpod, http/supabase_flutter | $0 | Open-source | Low | None | — |
| GitHub (private/public repo) | $0 | Free for this team size | None | None | — |

**Conclusion:** no item in the stack carries a plausible path to unexpected billing. The architecture is genuinely deployable at $0 for the MVP — this claim in the Technical doc's Final Decision is verified, not just asserted.

---

## PHASE 9 — 3-DAY FEASIBILITY AUDIT

**Critical Path (confirmed, not just repeated from Technical §17):** Instagram → Sheet → JSON data collection is the true bottleneck. Every screen after Day 1 depends on `providers.json` existing with real content; the code side of Day 1–2 can proceed against 3–5 dummy providers while data collection runs in parallel, but the **Day 3 Definition of Done (P2: 10–20 real providers × 3 categories = 30–60 providers, sourced, cropped 4:3, compressed, and manually vetted)** is the single largest amount of undifferentiated manual labor in the entire plan and has no code mitigation — it is a people/time problem, not an architecture problem.

**Bottlenecks, ranked:**
1. Real provider data + photos (people-hours, not engineering-hours — highest risk)
2. RLS policy correctness (must be tested Day 1, not discovered Day 3)
3. Device/emulator parity for the actual demo hardware (Technical §21 already flags this correctly)

**Parallel work confirmed feasible:** data collection (non-technical team member) running alongside Day 1–2 coding is explicitly already the plan (Technical §17) — correct call, keep it.

**Things likely to fail if compressed:** free-text search (already first on both cut lists — correct), custom transitions (already cut-first — correct), the "how we work" section (already Should-Have, cuttable — correct).

**Things to simplify further, beyond what's already specified:** none identified — the existing MUST-KEEP / SIMPLIFY / CUT-FIRST / DO-NOT-BUILD structure (Technical §20, Design §27) is already appropriately aggressive for a 3-day scope.

### 3-DAY SURVIVAL PLAN (unchanged from Technical §17, validated as sound)
- **Day 1:** project skeleton, router with all 5 routes (even as placeholders), `Provider`/`ContactRequest` models, Supabase table + RLS **tested with a real insert before end of day**, data collection begins in parallel from hour 0.
- **Day 2:** Home, Category (real cards + empty state), Provider Details (sticky CTA, Instagram link functional).
- **Day 3:** Contact flow + Supabase wiring, full integration test run twice on the actual demo device, offline-browsing check, final data swap-in if still pending.

---

## PHASE 10 — DESIGN-TECH COMPATIBILITY TABLE

| Design Element | Technical Support | Risk | Change Needed |
|---|---|---|---|
| Cairo via `google_fonts` | Native package, no manual font files | None | None |
| Borders instead of shadows | `CardTheme(elevation: 0, shape: RoundedRectangleBorder(side: BorderSide(...)))` | None | None |
| 4:3 image ratio + `BoxFit.cover` | Native `AspectRatio` + `Image` widgets | None | None |
| Sticky bottom CTA on Details | `Scaffold.bottomNavigationBar` or `Positioned` — both standard | None | None |
| Simple `PageView` image gallery, optional dot indicator | Native Flutter widget, no package needed | None | None |
| RTL via `Directionality`/`locale: ar` | Native `MaterialApp` support | None | None |
| Secondary-color badge icon (`#D9A05B`) | Fully implementable | **[NEEDS FIX — accessibility, see Phase 4]** | Recolor icon to Text Secondary or Primary; keep `#D9A05B` for border/fill accents only |
| Optional 1dp shadow on primary button | `BoxShadow` inline, explicitly marked cuttable | None | None |
| Disabled/loading state on submit button | Riverpod `AsyncValue` + `ElevatedButton(onPressed: null)` pattern | None | None |

**No package in the Design doc requires anything beyond what's already in the Technical stack.** Design §26's self-assessment ("no conflict found") is verified correct, with the one addition above (badge icon contrast) that Design's own audit missed.

---

## PHASE 11 — PRODUCT ↔ UX TRACEABILITY (every MUST checked)

| Product MUST | Present in UX/Design? | Where | Status |
|---|---|---|---|
| Instagram link always visible, never hidden | Yes | Details screen, secondary button | ✅ (see note below) |
| "تمت مراجعة بياناته من فريق sawa" text, exact wording | Yes | Card (badge) + Details screen | ✅ |
| No word "موثّق"/"تم التحقق" anywhere | Yes, actively designed against (Design §1, §3) | Global | ✅ |
| No response-time promise | Yes, actively designed against | Global copy (§24 Microcopy) | ✅ |
| No provider phone number on card | Yes | Card has no contact button (§16 point 6) | ✅ |
| Contact request routed through sawa, not direct | Yes | Contact Request screen → Supabase | ✅ |
| Optional fields hidden silently, no "N/A" text | Yes | Explicitly called "قرار منتج غير قابل للتفاوض" in Design §18 handoff | ✅ |

**Note on Instagram link placement:** Product only requires the link be *available and unhidden* — it does not mandate card-level placement. Design's choice to surface it only on Details (one tap deeper) is compliant. **[RECOMMENDATION, non-blocking]:** since Product Spec's Strategic Differentiation section treats this link as core to trust-building ("قناة إطلاق حقيقية... رابط... متاح للمستخدم لبناء ثقته الخاصة"), consider a small Instagram glyph on the card itself in a future iteration — not required for MVP, flagged only for completeness.

---

## PHASE 12 — REQUIREMENTS TRACEABILITY MATRIX (MUST-tier only)

| ID | Requirement | Source | Product | UX | Design | Technical | Data | Testing | Demo | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| P1 | 3 categories, Baghdad only | Product | ✅ | ✅ | ✅ | ✅ | ✅ | — | ✅ | Ready |
| P2 | 10–20 real providers/category | Product | ✅ | — | — | ✅ (pipeline) | **[GAP]** data not yet collected | — | ✅ (blocks demo) | **NEEDS FIX** |
| P3 | Organized card (photo, info, price if avail.) | Product | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ (widget test) | ✅ | Ready |
| P4 | Category filter | Product | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ (unit test) | ✅ | Ready |
| P5 | Contact request via sawa | Product | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ (widget+integration) | ✅ | Ready |
| P6 | Instagram link never hidden | Product | ✅ | ✅ | ✅ | ✅ | ✅ | — | ✅ | Ready |
| P7 | "reviewed by sawa" text | Product | ✅ | ✅ | ✅ (⚠️ badge contrast) | ✅ | ✅ | — | ✅ | **NEEDS FIX** (contrast) |
| P8 | Honest follow-up message | Product | ✅ | ✅ | ✅ | ✅ | — | — | ✅ | Ready |
| B1 | No "موثّق" anywhere | Product | ✅ | ✅ | ✅ | N/A | N/A | — | ✅ | Ready |
| B2 | No SLA promise | Product | ✅ | ✅ | ✅ | N/A | N/A | — | ✅ | Ready |
| M1 | Zero-crash live flow | Demo | — | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | Ready (pending implementation) |
| M2 | Offline browsing works | Demo | — | ✅ | ✅ | ✅ (local assets) | ✅ | — | ✅ | Ready (contingent on local-assets decision being executed) |

No **[UNNECESSARY]** items were found — nothing in Technical or Design implements a feature that isn't traceable to a Product requirement. This is a tightly scoped chain.

---

## PHASE 13 — DATA FLOW AUDIT

```
Instagram (manual source)
 → Google Sheet (one column per Provider field)
 → CSV export
 → providers.json
 → assets/data/providers.json (bundled)
 → ProvidersRepository.getAll() [rootBundle.loadString()]
 → providersListProvider (Riverpod FutureProvider, cached)
 → CategoryScreen / ProviderCard / ProviderDetailsScreen
```

| Provider field | Reaches UI? | Where | Notes |
|---|---|---|---|
| `id` | Yes | Routing key only, not rendered | Correct — internal use |
| `name` | Yes | Card + Details (Heading) | ✅ |
| `category` | Yes | Drives filtering, not directly rendered as text on card | ✅ (used structurally) |
| `images[]` | Yes | Card (1 image) + Details (gallery) | ✅ |
| `priceRangeText` (optional) | Yes, conditionally | Card + Details | ✅ hidden-if-null, matches DA3 |
| `shortDescription` (optional) | Yes, conditionally | Card + Details | ✅ |
| `instagramUrl` | Yes | Details secondary button | ✅ |
| `city` | **Not rendered anywhere** | — | **[UNNECESSARY, mild]** — field exists in the model but every provider has the same value ("بغداد") in this MVP, and Design §17 explicitly chose to fold it into description rather than show it standalone. Not a bug — a deliberate, documented simplification. No fix needed. |
| `reviewedBySawa` | Yes | Card + Details badge | ✅ |

`ContactRequest`: every field (`providerId`, `userName`, `userContact`, `note`, `createdAt`) maps 1:1 to either the form (Design §18) or system-generated metadata (`createdAt`, `providerId` from route). **No missing, duplicated, or inconsistently-named fields found.**

---

## PHASE 14 — USER JOURNEY STRESS TEST

| Step | What the user sees | Could confuse them? | Could fail? | Missing-data behavior | No-internet behavior |
|---|---|---|---|---|---|
| 1. Open | Home, 3 category tiles | No — deliberately minimal | Unlikely (no network call) | N/A | Works fully — no network needed |
| 2. Choose category | CategoryScreen list | No | Empty category if data collection fell short | `EmptyStateView`, honest copy | Works — local JSON |
| 3. Browse/compare | ProviderCards | No — consistent layout | Missing image → error icon, card survives (Design §11) | Optional fields silently hidden | Works if images are local assets |
| 4. Open details | Full info + gallery | No | Same as above | Same | Works if local assets |
| 5. Check Instagram (optional) | External browser opens | No | Broken/dead Instagram link (data-entry error, not code) | **[GAP not covered by any doc]** — no fallback UI specified if `url_launcher` fails to open a bad URL | Requires internet at this exact optional step — acceptable, since it's explicitly optional and external |
| 6. Request contact | Form, 3 fields | No | Validation is intentionally minimal (non-empty only) | N/A | Requires internet — this is the one step that must work live or gracefully degrade |
| 7. Submit | Loading spinner in button | No | Supabase down / RLS misconfigured / no signal | Error message + retry button (Design §18, honest copy, no false-success) | Handled correctly — no silent failure |
| 8. Success | Confirmation text | No | N/A | N/A | N/A |
| 9. Team receives request | (backstage) Supabase Table Editor | N/A | Team not actively monitoring during demo | N/A | N/A |

**One real gap found:** step 5 has no documented behavior if `url_launcher` fails to open a malformed/dead Instagram URL (e.g., a typo during manual data entry). **[RECOMMENDATION]:** wrap the launch call in a try/catch with a one-line snackbar ("تعذّر فتح الرابط") — trivial to add, not currently specified anywhere, low risk if skipped since it's a secondary, optional action, but cheap enough to include in the Day 2 build for completeness. Not elevated to MUST since no document requires it and it does not block the core flow.

---

## PHASE 15 — DEMO FAILURE TEST / DEMO SAFETY PLAN

| Failure | Impact | Probability | Prevention | Fallback |
|---|---|---|---|---|
| Room internet fails | Browsing unaffected (local assets); contact submission fails | Medium (hackathon venues are unreliable) | Confirm local-assets decision is actually implemented, not left as "later" | Narrate the flow verbally at the submit step: "in a live environment this reaches our team instantly" — acceptable, honest framing |
| Supabase misconfigured/down | Contact submission fails | Low if RLS tested Day 1 as planned | Day-1 RLS insert test (already scheduled) | Google Form fallback pre-wired, not built from scratch under pressure |
| Image fails to load | One card/detail looks broken | Low if local assets used | Local assets (already the recommendation) | `errorWidget` fallback already specified (Technical §13) |
| Provider data incomplete/missing | Category looks empty or thin | **Highest-probability failure in the whole project** (Phase 9) | Start data collection hour 0, in parallel with code, per plan | Dummy providers as last-resort visual filler — explicitly *not* to be presented as real if used, to protect the honesty positioning that is the entire product thesis |
| Empty category (0 providers) | `EmptyStateView` shown live to judges | Low if data collection succeeds | Same as above | Honest empty-state copy already reads well even if triggered live ("لا يوجد مزودون مطابقون حالياً") — not catastrophic even in worst case |
| Form validation fails | User can't submit | Low — validation is deliberately minimal | Already minimal by design | N/A |
| App crash | Demo halts | Low if integration test run twice pre-demo (already required) | Definition-of-Done already requires 2 consecutive clean runs on the actual demo device | Have a secondary device/emulator as backup, not currently documented — **[RECOMMENDATION]:** add a backup device to the Day 3 checklist |
| Slow loading | Perceived sluggishness | Low — data is tiny (30–60 items, local) | Already mitigated by architecture choice | N/A |
| Request not received (silent failure) | Undermines the entire "نتابع طلبك" promise if unnoticed | Low — explicit anti-silent-failure requirement in Product Philosophy | Error state always shown, never a false success (Technical §10, Design §18) | N/A |

**[RECOMMENDATION — added to plan]:** bring a second device/emulator pre-loaded and tested, in case the primary demo device fails on the day. This is the only net-new mitigation this review adds beyond what the three source documents already specify.

---

## PHASE 16 — SECURITY / PRIVACY AUDIT

- Supabase anon key: kept in `.env`/`--dart-define`, `.gitignore`'d — **[FACT, Technical §14]**. Correct practice even though anon keys are designed to be client-exposed.
- RLS: insert-only for `contact_requests`, no client-side select/update/delete — **[FACT]**. This is the correct minimal policy for the use case.
- User contact info (name, phone) is only readable from the Supabase dashboard by the team, not from the client — matches the honesty principle (no one but the team can see who asked what).
- Provider data is intentionally public (it's already public on Instagram) — no protection needed, correctly not over-engineered.
- No authentication system exists anywhere — appropriate, since Product Spec explicitly forbids building one for this version.
- **No security items require anything beyond MVP-appropriate measures.** Nothing here needs escalation.

---

## PHASE 17 — UX COPY AUDIT

| Copy | Clarity | Natural Arabic (Iraqi) | Over-promising? | Verdict |
|---|---|---|---|---|
| "أهلاً بيك بـsawa. اختر الفئة التي تدوّر عليها." | Clear | Yes, natural Iraqi dialect | No | ✅ |
| "تمت مراجعته من فريق sawa" (locked) | Clear | Neutral/standard, appropriately formal for a trust claim | No — deliberately hedged | ✅ Do not alter |
| "نتابع طلبك ونساعدك بالتواصل مع المزوّد" (locked) | Clear | Neutral/standard | No — no time bound, no guarantee | ✅ Do not alter |
| "فريقنا راح يتواصل وياك قريباً" (Success screen, secondary line) | Clear | Natural Iraqi | **[MINOR FLAG]** — "قريباً" (soon) is a soft, undefined time reference. It doesn't violate the letter of Product Decision #2 (no *specific* time promise), but it edges toward implying speed the team hasn't validated (Product Spec explicitly says any time-bound language needs "قرار منفصل لاحق"). | **[NEEDS FIX, minor]** — reword to something time-neutral, e.g., "فريقنا بيتواصل وياك." Flagged, not changed here since this is Design-authored copy, not a locked Product Decision, and belongs to Design's revision, not this review's unilateral edit. |
| "ما كدرنا نرسل طلبك، حاول مرة ثانية." | Clear | Natural Iraqi | No | ✅ |
| "لا يوجد مزودون مطابقون حالياً." | Clear | Slightly more formal register than the rest of the copy, but not jarring | No | ✅ |

**One actionable copy fix identified** (the "قريباً" line) — everything else passes.

---

## PHASE 18 — COMPETITOR RESEARCH CONSISTENCY CHECK

Checking Product/Design decisions against Research's own AVOID and LEARN lists:

- **AVOID: single repetitive app-download CTA wall (The Knot).** sawa's design does not replicate this — every screen has one clear action but the flow is fully in-browser/in-app functionality, not a download wall. ✅ Lesson applied.
- **AVOID: vendor lead-gen models that create adversarial incentives (WeddingPro).** sawa's MVP has no vendor-facing monetization at all yet — this isn't "solved," it's correctly deferred, and the Product Spec explicitly names this tension as a future risk to design around. ✅ Lesson acknowledged, not ignored.
- **AVOID: overloaded mega-menus (Paperless Post, The Knot).** sawa has 3 categories, zero mega-menus. ✅ Trivially avoided given the MVP's tiny scope — not really a risk here either way.
- **LEARN: explicit, self-stated tiering logic (Evite).** Not directly applicable — sawa has no free/paid split for users in this MVP. Correctly not borrowed since it doesn't apply.
- **LEARN: guest-facing structured Q&A recurs as a genuinely useful pattern (Partiful/Evite/Paperless Post).** Not adopted — correctly out of scope, since sawa's MVP has no guest-side flow at all (no wedding website/RSVP layer in this version). Appropriately not copied just because competitors have it.
- **No evidence of "feature creep from competitor envy"** — Technical/Design/Product do not add anything traceable only to "because WeddingWire/Zola has it." The MVP stays scoped to what Product Spec asked for.

**Conclusion:** the Research doc's findings were used selectively and correctly — as cautionary lessons and as an evidence base for *not* copying vendor-marketplace pitfalls, not as a feature checklist to imitate. This is exactly how a forensic research doc should be used at this stage.

---

## PHASE 19 — BUILD READINESS SCORECARD

| Area | Status | Notes |
|---|---|---|
| Product | **READY** | Requirements are clear, locked decisions well-justified; one wording ambiguity (C1) noted, non-blocking |
| Requirements | **READY** | Full traceability achieved for all MUST items |
| Data | **BLOCKED** | Real provider dataset (30–60 entries with photos) does not yet exist — this is the true critical path, not a code problem |
| UX | **READY** | Journey is complete, no dead ends, one minor url_launcher edge case unhandled (low priority) |
| Design | **NEEDS FIX** | Badge icon contrast (Phase 4/10), one copy line ("قريباً"), and the A/B/C direction confirmation are outstanding but all cheap to resolve |
| Architecture | **READY** | Stack, layering, and state management are all justified and internally consistent |
| Backend | **NEEDS FIX** | Not broken, but RLS must be *tested*, not just configured, before it can be called Ready — currently scheduled correctly for Day 1 |
| Testing | **READY** (plan only) | Test plan is appropriately minimal and correctly prioritizes the integration flow; no tests exist yet since implementation hasn't started |
| Demo | **NEEDS FIX** | Plan is sound; add a backup device and confirm data collection is truly running in parallel from hour 0 |

No area is **UNKNOWN** — every category has enough source material to be evaluated. The project is in genuinely good shape for a 3-day hackathon; the dominant risk is **people-hours on data collection**, not engineering or design decisions.

---

## PHASE 20 — FINAL REVISIONS

| Old Decision | Problem | New Decision | Why |
|---|---|---|---|
| Badge icon rendered in Secondary `#D9A05B` | ~2:1 contrast against light surfaces, below 3:1 minimum for meaningful UI graphics | Render badge icon in Text Secondary (`#6B5F58`) or Primary (`#B5654A`); reserve `#D9A05B` for thin borders/fills only | The badge carries the project's core trust claim — it must not be the least legible element on the card |
| Success screen secondary line: "فريقنا راح يتواصل وياك قريباً" | "قريباً" edges toward an implied speed promise the team hasn't validated, against the spirit (if not the letter) of Product Decision #2 | Reword to a time-neutral equivalent, e.g., "فريقنا بيتواصل وياك." | Keeps the copy honest and internally consistent with the locked no-SLA principle |
| Product Spec journey line "لا رقم تواصل مباشر مطلوب لإرسال الطلب" | Ambiguous — reads as if the user's own phone number is optional | Clarify in the next Product Spec revision to explicitly say "لا رقم تواصل مباشر **للمزوّد**" | Removes ambiguity for future readers; Technical/Design already implement the correct interpretation, so no code/design change needed |
| No documented fallback if `url_launcher` fails on a bad Instagram URL | Small, silent-failure risk on an optional but trust-relevant action | Wrap the launch call in try/catch with a one-line snackbar ("تعذّر فتح الرابط") | Cheap, consistent with the project's overall no-silent-failure principle |
| Demo checklist has no backup device | Single point of failure if the primary demo device breaks | Add "pre-loaded backup device/emulator, tested" to the Day 3 checklist | Low-cost mitigation against the highest-impact possible failure (demo halts entirely) |

No other changes are recommended. Everything else in Product, Technical, and Design is internally consistent, appropriately scoped, and ready to build against as-is.

---

# SAWA — FINAL MASTER SPECIFICATION
*(Synthesis of Product Spec + Technical Architecture + Design System, with the five revisions above applied. This section is what Claude #4 should build from.)*

## 1. Product Overview
sawa is a Baghdad-only, hackathon-MVP marketplace app that curates real event-service providers (halls, photographers, decor) into one organized, team-reviewed listing, and routes contact requests through sawa instead of leaving users to cold-message providers on Instagram.

## 2. Product Philosophy
"Documented quality over unverified quantity. Honesty in the promise over first impression." No claim is made that cannot currently be backed operationally.

## 3. Problem
Baghdad users choosing wedding/event providers are stuck between Instagram (large but unreliable, slow/no replies) and dead local apps ("قاعات", "مناسبات" — outdated, thin, abandoned).

## 4. Target User
Primary: engaged couples (bride typically chooses, groom typically pays — both are real users). Providers are not users in this version; their data is team-managed.

## 5. JTBD
"When I'm trying to find a wedding-event provider in Baghdad, I want an organized, team-reviewed list with real follow-up on my contact request, so I don't get lost in Instagram chaos or ghosted by a dead local app."

## 6. Value Proposition
A curated, team-reviewed provider directory in one organized place, with genuine follow-up on every contact request — as opposed to random Instagram search or abandoned local apps.

## 7. Strategic Differentiation
- Never claims "موثّق"/verified — only "تمت مراجعته من فريق sawa."
- Never promises a response-time SLA.
- Never hides the provider's original Instagram source — sawa's value is being the easier, more organized contact channel, not the gatekeeper.
- Real launch channel: a personal Instagram account (1,700 followers) with inherited personal trust.

## 8. Business Direction
Out of scope for this MVP by design. No payment gateway, no vendor subscriptions, no commission model built or claimed. Future direction (not built): tiered verification, SLA once tested, vendor self-service login, other categories/cities.

## 9. MVP Scope
**Must:** 3 categories (halls, photographers, decor) × Baghdad; 10–20 real providers/category; organized provider cards; category filter; contact request through sawa; visible Instagram source link; "reviewed by sawa" text; honest follow-up message.
**Should:** short "how we work" section; non-functional vendor-dashboard mockup for the pitch deck only.
**Do Not Build:** real payments, live availability calendar, full vendor dashboard, ratings/reviews system, any social feature, complex multi-role login, hiding the provider's original link, any unfulfillable "verified"/SLA claim.

## 10. Requirements
See Phase 1 Requirements Master List and Phase 12 Traceability Matrix above — both apply in full as the requirements baseline.

## 11. User Journey
Open → choose category → browse/compare cards → open provider details → (optional) check Instagram → tap "طلب تواصل" → fill 3-field form → submit → honest confirmation → return home. Team monitors Supabase manually behind the scenes; no automation required for MVP.

## 12. Information Architecture
Fully linear, 5 screens, no Drawer, no Bottom Navigation. Home (category decision) → Category (provider decision) → Details (contact decision) → Contact (execution) → Success (confirmation). Each screen asks for exactly one primary decision.

## 13. Screen Specifications
1. **HomeScreen** — 3 category tiles, no scroll, no secondary actions.
2. **CategoryScreen** — AppBar + (optional Should-Have search field) + `ListView.builder` of full-width `ProviderCard`s + `EmptyStateView` if no matches.
3. **ProviderDetailsScreen** — image gallery (`PageView`) → name → category/description → price if available → "reviewed by sawa" badge → Instagram secondary button → sticky bottom primary "طلب تواصل" button.
4. **ContactRequestScreen** — name (required), phone (required), note (optional); submit button disabled until required fields filled; loading state inside the button; honest error state with retry on failure.
5. **ContactSuccessScreen** — success icon, locked confirmation text, one corrected secondary line ("فريقنا بيتواصل وياك"), one "return home" button, no secondary CTA.

## 14. UX Rules
One primary CTA per screen. No fake urgency, no scarcity language, no social proof numbers that aren't real. Optional fields hide silently when null — never render "غير متوفر." Provider phone number is never shown on the card. Full flow must work with zero internet if images are local assets (confirmed as the storage decision, see §23).

## 15. Visual Identity
**Direction A — "Organized Notebook."** Warm, honest, calm, purposeful, locally warm (not corporate-cold, not Western-wedding-cliché, not another Instagram feed). **[OPEN DECISION carried forward, not resolved by this review]:** final A vs. B confirmation is a pitch-strategy call for the team, not a pure design call — proceed with A as the working default per the Design doc's own recommendation, switchable via tokens alone if the team decides otherwise before Day 1 ends.

## 16. Design System
Flat, border-based (no shadows except an optional 1dp accent on the primary button), Cairo typeface throughout (Arabic + the limited Latin text), RTL-first via `MaterialApp(locale: Locale('ar'))`, 4:3 image ratio everywhere, radius 12 for cards/fields/images and 8 for buttons.

## 17. Design Tokens
```
Colors:
  primary:        #B5654A
  secondary:      #D9A05B   // borders/fills ONLY — never a standalone icon/text color (Phase 20 fix)
  background:     #FBF7F2
  surface:        #FFFFFF
  textPrimary:    #2B2320
  textSecondary:  #6B5F58
  border:         #E4D9CF
  success:        #4C7A5E
  error:          #B3442F
  warning:        #C48A3F   // reserved, unused in MVP

Typography (Cairo):
  h1: 22sp/700, h2: 18sp/600, body: 15sp/400,
  bodySmall: 13sp/400, caption: 12sp/400, button: 15sp/600
  line-height: 1.4x throughout

Spacing: 4, 8, 12, 16, 24, 32
Radius: card/field/image = 12, button = 8
Elevation: 0 by default; optional 1 on primary button only
Icon sizes: inline 20, standalone 24
Touch target min: 48x48
```

## 18. Technical Architecture
Flutter (stable) + Dart, MVVM-simplified + Repository (no Domain layer), Riverpod, go_router. No dedicated backend — static local JSON for reads, one Supabase table for writes.

## 19. Flutter Structure
As specified in Technical Architecture §4 — `core/` (theme, router, constants, shared widgets), `features/providers_list`, `features/provider_details`, `features/contact_request`, `data/local/assets/providers.json`. Screens never import from `data/`; repositories never import widgets.

## 20. State Management
Riverpod throughout. `FutureProvider` for the cached provider list, feature-level Notifiers for filtering and contact-request submission state, `AsyncValue` for loading/error/empty rather than scattered booleans. Local form controllers stay as plain widget state.

## 21. Navigation
`go_router`, fully linear, 5 named routes, default transitions only (no custom animation — first item on both cut lists).

## 22. Data Model
`Provider`: id, name, category (enum: hall/photography/decor), images[] (≥1, required), priceRangeText (optional), shortDescription (optional), instagramUrl (required, never hidden), city (fixed "بغداد" for MVP), reviewedBySawa (fixed true).
`ContactRequest`: providerId, userName (required), userContact (required — see Phase 20 C1 resolution), note (optional), createdAt.

## 23. Provider Data Pipeline
Instagram (manual collection) → Google Sheet → CSV export → `providers.json` → bundled asset → `ProvidersRepository.getAll()` via `rootBundle.loadString()`. New/updated provider = re-export + rebuild, no server involved. **Image storage: local assets, confirmed** (Phase 6 decision), `cached_network_image` kept as a ready dependency for a post-hackathon swap to remote URLs.

## 24. Database
Provider reads: static JSON asset (not a database). Contact-request writes: one Supabase Postgres table (`contact_requests`), no auth, RLS = insert-only for the client. Fallback: Google Form if Supabase setup fails or time runs out.

## 25. Contact Request Flow
3-field form (name, phone, optional note) → submit → loading state in-button → Supabase insert (or Google Form fallback) → success screen with locked copy, or an honest retry-able error state on failure. No automated team notification in MVP — the team watches the Supabase Table Editor manually.

## 26. Security
Anon key via `.env`/`--dart-define`, gitignored. RLS: insert-only, no client-side select/update/delete on `contact_requests`. Provider JSON is intentionally public. No authentication system built.

## 27. Performance
`ListView.builder`, `const` widgets where possible, Riverpod `select` to avoid full-screen rebuilds, provider JSON loaded once and cached via `FutureProvider`. No pagination, no isolates — unjustified at this data scale.

## 28. Testing
Unit: JSON parsing/model mapping (including missing optional fields), contact-request payload construction (mocked), category-filter logic.
Widget: `ProviderCard` renders correctly with/without optional fields, `ContactRequestScreen` submit button disabled until required fields filled, `EmptyStateView` renders on empty filtered list.
Integration (highest priority): Home → Category → Details → Contact → fill form → submit → Success, run clean at least twice on the actual demo device before presenting.

## 29. Demo Safety Plan
See Phase 15 table in full. Key gates: RLS insert tested Day 1 (not Day 3); local image assets confirmed and used (not URLs) for the live demo; honest, non-silent failure states on every network-dependent step; a pre-tested backup device brought to the demo (new addition, Phase 20).

## 30. 3-Day Execution Plan
As in Technical Architecture §17, validated sound in Phase 9 above — Day 1: foundation + navigation skeleton + data pipeline start + RLS test; Day 2: browsing/details screens with real repository data; Day 3: contact flow + full integration testing + demo-device rehearsal, with data collection running in parallel from hour 0 throughout.

## 31. Team Responsibilities
Solo / 2-dev / 3-dev splits as specified in Technical Architecture §18 — unchanged, no revision needed; all three splits correctly gate on agreeing the `Provider`/`ContactRequest` models before any parallel work begins.

## 32. MVP Cut List
**Cut first if time is short:** free-text search, custom screen transitions, image-gallery dot indicator, "how we work" section.
**Never cut (locked Product Decisions):** the 5 core screens, real provider data (10–20/category minimum), the Instagram link, the two locked copy strings, the contact-request-through-sawa flow.

## 33. Known Risks
Ranked by this review: (1) real provider data collection running out of time — highest probability, highest impact, mitigated only by starting at hour 0; (2) RLS misconfiguration — mitigated by Day-1 testing; (3) demo-room internet loss — mitigated by local image assets and an honest verbal fallback for the contact step; (4) single demo-device failure — mitigated by the newly added backup-device checklist item.

## 34. Open Decisions
- **[OPEN DECISION D1]:** Visual Direction A vs. B — Design recommends A as default; final confirmation is a team/pitch-strategy call, not purely a design one.
- **[OPEN DECISION]:** Icon package (Material vs. Phosphor/Lucide) — functionally equivalent, team's call based on remaining time.
- **[OPEN DECISION]:** whether to invest the small effort in the `url_launcher` try/catch fallback (Phase 14) — low risk either way, cheap to include.

## 35. Acceptance Criteria
Product: every MUST requirement present, no feature became mandatory without a Product source, philosophy and MVP stay consistent (verified, Phase 12). UX: primary journey works end-to-end, no dead ends, contact flow is clear (verified, Phase 14). Design: visual system consistent, RTL handled, implementable in 3 days (verified, Phase 10, with the one badge-contrast fix applied). Technical: architecture supports all MUST features, no paid dependency, no unnecessary backend, data pipeline realistic (verified, Phase 8–9). Data: provider schema supports the UI, JSON mapping complete, missing data handled (verified, Phase 13). Demo: critical flow works, fallbacks exist, a real contact request can be demonstrated (verified, Phase 15).

## 36. Final Handoff to Flutter Developer
Build directly from Technical Architecture §HANDOFF and Design §HANDOFF as originally written, with these five amendments layered on top:
1. Badge icon: use Text Secondary or Primary color, not `#D9A05B`, for the "reviewed by sawa" check icon.
2. Success-screen secondary line: use "فريقنا بيتواصل وياك" instead of "...قريباً."
3. Treat `userContact` as required in both the model and the form — this is already what both source docs implement; the Product Spec's ambiguous sentence refers to the provider's number, not the user's own.
4. Wrap the Instagram `url_launcher` call in a try/catch with a one-line snackbar fallback.
5. Add a pre-tested backup device/emulator to the Day-3 pre-demo checklist.

Nothing else in the three source documents needs to be re-decided. Proceed to implementation.

---
*End of SAWA_FINAL_MASTER_SPEC.md — produced after full COLLECT → MAP → COMPARE → CRITIQUE → ALTERNATIVES → STRESS TEST → REVISE → VALIDATE → FINALIZE pass across Research, Product, Technical, and Design sources.*
