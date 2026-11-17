-- Supabase exposes the public schema through its REST API (PostgREST) as the anon and
-- authenticated roles. Only this backend talks to the database, so close that door: turn on
-- RLS with no policies (denies those roles every row) and revoke their privileges outright.
-- The backend connects as the table owner, which RLS does not apply to.
DO $$
DECLARE
    t RECORD;
BEGIN
    -- Flyway holds a lock on its history table while migrating, so altering it here hangs.
    -- The REVOKE below still shuts anon out of it.
    FOR t IN SELECT tablename FROM pg_tables WHERE schemaname = 'public'
                       AND tablename <> 'flyway_schema_history' LOOP
        EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t.tablename);
    END LOOP;

    -- These roles only exist on Supabase, not in the local docker Postgres.
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon')
       AND EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
        REVOKE ALL ON ALL TABLES IN SCHEMA public FROM anon, authenticated;
        REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM anon, authenticated;
        REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM anon, authenticated;
        ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON TABLES FROM anon, authenticated;
        ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON SEQUENCES FROM anon, authenticated;
        ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON FUNCTIONS FROM anon, authenticated;
    END IF;
END $$;
