-- "Ton année Wishy" moves from December to December 26 - January 15: shown
-- from December 1, the recap missed the gifts of Christmas, and a card hidden
-- before Christmas never came back.
-- start and end are [month, day], read by the app from 1.1.1 (same defaults
-- in card_builders.dart and supabase-tests/home_cards.sql: keep the three in
-- sync). The recap is the one of the year that ends, so the window can also
-- sit in January only (e.g. [1, 2] to [1, 31]) without a release.
-- month = 0 is for 1.1.0, which only reads month (12 when absent): no month
-- ever matches, so it no longer shows the card at all.
-- Idempotent: a customised window is never overwritten.
UPDATE public.home_cards
SET params = params || '{"month": 0, "start": [12, 26], "end": [1, 15]}'::jsonb,
    updated_at = now()
WHERE key = 'year_recap'
  AND NOT params ? 'start';
