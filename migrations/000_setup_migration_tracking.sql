-- Quick Start: Migration Tracking Setup
-- Run this first in your Supabase SQL Editor to enable migration tracking

-- Create migration tracking table
CREATE TABLE IF NOT EXISTS public.schema_migrations (
  version VARCHAR(255) PRIMARY KEY,
  applied_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  description TEXT
);

-- Enable RLS on migration tracking
ALTER TABLE public.schema_migrations ENABLE ROW LEVEL SECURITY;

-- Allow authenticated users to read migration status
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'schema_migrations' 
    AND policyname = 'Allow authenticated users to read migrations'
  ) THEN
    CREATE POLICY "Allow authenticated users to read migrations" 
    ON public.schema_migrations FOR SELECT TO authenticated USING (true);
  END IF;
END $$;

-- Grant read access to authenticated users
GRANT SELECT ON public.schema_migrations TO authenticated;

-- Record the initial migration if running on existing database
INSERT INTO public.schema_migrations (version, description) 
VALUES ('001_initial_schema', 'Initial schema setup for The Borrowed Wings app')
ON CONFLICT (version) DO NOTHING;

-- Verify setup
SELECT 
  'Migration tracking setup complete!' as status,
  COUNT(*) as migrations_recorded 
FROM public.schema_migrations;