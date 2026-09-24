-- ═════════════════════════════════════════════════════════════════════════════
-- SAWA v2 — Migration 600: category taxonomy
-- ═════════════════════════════════════════════════════════════════════════════
-- Categories may exist with zero providers — the app shows an honest empty
-- state. No providers are created here (real listings arrive in Phase 7).
-- Re-running updates names/icons/order but never re-activates a category an
-- operator has deactivated.
-- ═════════════════════════════════════════════════════════════════════════════

insert into public.categories (id, name_ar, name_en, icon_key, sort_order)
values
  ('halls',       'قاعات المناسبات',   'Wedding & Event Halls', 'building',    10),
  ('photography', 'التصوير',            'Photography',           'camera',      20),
  ('flowers',     'الورد والزهور',      'Flowers',               'flower',      30),
  ('decoration',  'الديكور والتنسيق',   'Decoration',            'sparkle',     40),
  ('beauty',      'التجميل',            'Beauty',                'makeup',      50),
  ('catering',    'الضيافة والطعام',    'Catering',              'fork_knife',  60),
  ('music',       'الموسيقى والفرق',    'Music & Bands',         'music',       70),
  ('cars',        'سيارات المناسبات',   'Event Cars',            'car',         80),
  ('invitations', 'الدعوات',            'Invitations',           'envelope',    90),
  ('other',       'خدمات أخرى',         'Other Event Services',  'dots',       100)
on conflict (id) do update
  set name_ar    = excluded.name_ar,
      name_en    = excluded.name_en,
      icon_key   = excluded.icon_key,
      sort_order = excluded.sort_order;
