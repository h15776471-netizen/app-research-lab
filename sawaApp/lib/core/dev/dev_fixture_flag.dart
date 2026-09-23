/// Debug-only switch to preview screens against
/// `assets/data/dev_fixture_providers.json` instead of the real (currently
/// empty) `assets/data/providers.json`.
///
/// MUST stay `false` by default. Never flip this in a release or demo
/// build — Skill Module 2 (Scope Guardian) / Module 5 (Data Integrity):
/// "final demo data must be real, never fabricated." Flip it locally only
/// while building/reviewing screens without real data yet, and flip it
/// back to `false` before committing or building for demo.
const bool kUseDevFixtureProviders = false;
