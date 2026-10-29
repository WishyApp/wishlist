-- Keywords that find the birthday wishlist of the user by its name, for the
-- after-party card (same rule as the `keywords` of `christmas`): lower case,
-- without accents, single words. Idempotent: running it again changes nothing.
UPDATE public.home_cards
SET params = params || '{"birthday_keywords": ["anniv", "anniversaire", "birthday", "bday"]}'::jsonb
WHERE key = 'after_party';
