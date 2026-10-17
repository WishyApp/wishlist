-- Every foreign key of a public table has an index
-- (20261012130000_add_foreign_key_indexes).
--
-- Runs after all migrations, as postgres, in a transaction rolled back at the
-- end. Any unexpected result raises an error.

BEGIN;

DO $$
DECLARE
  fk record;
  missing text := '';
  checked int := 0;
BEGIN
  FOR fk IN
    SELECT c.conrelid, c.conrelid::regclass AS tbl, c.conname, c.conkey
    FROM pg_constraint c
    JOIN pg_class t ON t.oid = c.conrelid
    JOIN pg_namespace n ON n.oid = t.relnamespace
    WHERE c.contype = 'f' AND n.nspname = 'public'
  LOOP
    checked := checked + 1;
    -- An index covers the key when it is a valid btree index without a
    -- predicate and its leading key columns (INCLUDE columns don't count) are
    -- the key columns, in any order. An expression has indkey 0, so it never
    -- matches a key column. A partial index could serve the key too, but is
    -- rejected to keep the test simple.
    IF NOT EXISTS (
      SELECT 1 FROM pg_index i
      JOIN pg_class ic ON ic.oid = i.indexrelid
      WHERE i.indrelid = fk.conrelid
        AND ic.relam = (SELECT oid FROM pg_am WHERE amname = 'btree')
        AND i.indisvalid
        AND i.indpred IS NULL
        AND i.indnkeyatts >= cardinality(fk.conkey)
        AND (string_to_array(i.indkey::text, ' ')::int2[])[1:cardinality(fk.conkey)]
            @> fk.conkey
        AND (string_to_array(i.indkey::text, ' ')::int2[])[1:cardinality(fk.conkey)]
            <@ fk.conkey
    ) THEN
      missing := missing || format(' %s(%s)', fk.tbl, fk.conname);
    END IF;
  END LOOP;

  IF checked = 0 THEN
    RAISE EXCEPTION 'FAIL foreign key indexes: no foreign key found';
  END IF;
  IF missing <> '' THEN
    RAISE EXCEPTION 'FAIL foreign key indexes: no index on the key of:%', missing;
  END IF;
  RAISE NOTICE 'ok   foreign key indexes (% foreign keys, all indexed)', checked;
END $$;

ROLLBACK;
