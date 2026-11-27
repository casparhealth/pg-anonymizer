-- Reset the passwords of all login roles that came over in the snapshot (INF-2373).
-- A restored snapshot keeps every role with its original password, so without this the
-- anonymised DB (and any DB restored from it) would accept the source environment's
-- passwords. Each role gets a random password that is never printed; whoever needs a
-- role on the target environment sets a new password there.
-- The master user running this script and the RDS-managed roles are left alone.
-- Run: psql -v ON_ERROR_STOP=1 -d postgres -f reset-role-passwords.sql

DO $$
DECLARE
  r record;
  n int := 0;
BEGIN
  FOR r IN
    SELECT rolname FROM pg_roles
    WHERE rolcanlogin
      AND rolname <> current_user
      AND rolname !~ '^(rds|pg_)'
      AND NOT rolsuper
    ORDER BY rolname
  LOOP
    EXECUTE format('ALTER ROLE %I PASSWORD %L', r.rolname,
                   md5(random()::text || clock_timestamp()::text) || md5(random()::text));
    RAISE NOTICE 'password reset: %', r.rolname;
    n := n + 1;
  END LOOP;
  RAISE NOTICE '% role password(s) reset', n;
END
$$;
