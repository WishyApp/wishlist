-- Keywords that find the birthday wishlist of the user by its name, for the
-- after-party card (same rule as the `keywords` of `christmas`): lower case,
-- without accents, single words. `birthday_exclude_keywords` lists the words
-- of lists that are never the birthday one (a wedding anniversary).
-- Idempotent: a customised list is never overwritten.
-- Same defaults in card_builders.dart and supabase-tests/home_cards.sql: keep
-- the three in sync.
UPDATE public.home_cards
SET params = params || '{"birthday_keywords": ["anniv", "anniversaire", "birthday", "bday"]}'::jsonb
WHERE key = 'after_party'
  AND NOT params ? 'birthday_keywords';

UPDATE public.home_cards
SET params = params || '{"birthday_exclude_keywords": ["mariage", "wedding"]}'::jsonb
WHERE key = 'after_party'
  AND NOT params ? 'birthday_exclude_keywords';
