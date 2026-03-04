# Database Migrations for The Borrowed Wings

This directory contains database migration files for The Borrowed Wings paragliding logbook application. All migrations are designed to work with Supabase PostgreSQL.

## Migration Structure

```
migrations/
├── README.md                    # This file
├── 000_setup_migration_tracking.sql  # Migration system setup
├── 001_initial_schema.sql       # Initial database schema  
├── 002_your_next_migration.sql  # Next migration goes here
└── rollbacks/                   # Optional rollback scripts
    └── 002_rollback.sql
```

## Migration Naming Convention

- **Format**: `{sequence_number}_{descriptive_name}.sql`
- **Sequence**: Zero-padded 3-digit numbers (001, 002, 003, etc.)
- **Name**: Descriptive snake_case name describing the change
- **Examples**:
  - `002_add_flight_statistics.sql`
  - `003_alter_gliders_add_certification.sql`
  - `004_create_takeoff_sites_table.sql`

## Executing Migrations

### For New Database Setup

1. **Navigate to Supabase Dashboard**
   - Go to your project's SQL Editor
   - Open a new query

2. **Run Initial Schema**
   ```sql
   -- Copy and paste the contents of 001_initial_schema.sql
   -- Execute the entire migration script
   ```

3. **Verify Setup**
   ```sql
   -- Check tables were created
   SELECT table_name FROM information_schema.tables 
   WHERE table_schema = 'public';
   
   -- Check RLS is enabled
   SELECT tablename, rowsecurity FROM pg_tables 
   WHERE schemaname = 'public';
   ```

### For Existing Database Updates

1. **Check Current Migration Status**
   ```sql
   -- Create migration tracking table if it doesn't exist
   CREATE TABLE IF NOT EXISTS public.schema_migrations (
     version VARCHAR(255) PRIMARY KEY,
     applied_at TIMESTAMPTZ DEFAULT now() NOT NULL
   );
   
   -- Check which migrations have been applied
   SELECT * FROM public.schema_migrations ORDER BY version;
   ```

2. **Apply New Migration**
   ```sql
   -- Copy and paste the new migration SQL
   -- After successful execution, record the migration
   INSERT INTO public.schema_migrations (version) 
   VALUES ('002_your_migration_name');
   ```

3. **Verify Changes**
   - Test affected functionality in your application
   - Run relevant database queries to confirm changes
   - Check application logs for any related errors

## Migration Best Practices

### ⚠️ CRITICAL REQUIREMENTS

1. **BACKWARD COMPATIBILITY MANDATORY**
   - All migrations MUST be backward compatible
   - Existing application code should continue working after migration
   - Never remove columns, tables, or change data types that break existing queries

2. **MODIFY, DON'T RECREATE**
   - Use `ALTER TABLE` instead of `DROP TABLE` and `CREATE TABLE`
   - Use `ADD COLUMN` instead of recreating tables
   - Rename with `ALTER TABLE RENAME COLUMN` not drop/add

3. **SAFE SCHEMA CHANGES**
   ```sql
   -- ✅ GOOD: Adding new optional columns
   ALTER TABLE public.flights 
   ADD COLUMN landing_site TEXT;
   
   -- ✅ GOOD: Adding new tables
   CREATE TABLE IF NOT EXISTS public.takeoff_sites (
     id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
     user_id UUID REFERENCES auth.users(id),
     site_name TEXT NOT NULL,
     latitude NUMERIC,
     longitude NUMERIC
   );
   
   -- ✅ GOOD: Adding indexes
   CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_flights_landing_site 
   ON public.flights(landing_site);
   
   -- ❌ BAD: Removing columns (breaks existing code)
   ALTER TABLE public.flights DROP COLUMN duration_sec;
   
   -- ❌ BAD: Changing column types (can break existing data/code)
   ALTER TABLE public.flights ALTER COLUMN started_at TYPE DATE;
   
   -- ❌ BAD: Dropping tables
   DROP TABLE public.flights;
   ```

4. **SAFE DATA TYPE CHANGES**
   ```sql
   -- ✅ GOOD: Expanding constraints (string length increase)
   ALTER TABLE public.pilots 
   ALTER COLUMN full_name TYPE VARCHAR(500);
   
   -- ❌ BAD: Restrictive changes (shortening strings, adding NOT NULL)
   ALTER TABLE public.pilots 
   ALTER COLUMN full_name TYPE VARCHAR(50);
   ```

### Migration Development Workflow

1. **Test Locally First**
   - Create a local Supabase instance or test database
   - Apply migration and verify it works
   - Test that existing application functionality still works

2. **Write Idempotent Migrations**
   ```sql
   -- Use IF NOT EXISTS, IF EXISTS, CREATE OR REPLACE
   CREATE TABLE IF NOT EXISTS public.new_table (...);
   
   -- Check if column exists before adding
   DO $$ 
   BEGIN
     IF NOT EXISTS (
       SELECT 1 FROM information_schema.columns 
       WHERE table_name = 'flights' AND column_name = 'new_column'
     ) THEN
       ALTER TABLE public.flights ADD COLUMN new_column TEXT;
     END IF;
   END $$;
   ```

3. **Include Rollback Strategy**
   - Document what the rollback process would be
   - For critical changes, create rollback scripts in `rollbacks/` folder
   - Test rollback procedures in development

4. **Update Documentation**
   - Update API documentation if schema changes affect endpoints
   - Update model documentation in code comments
   - Add migration notes to changelog/release notes

### Column Addition Guidelines

When adding new columns:

```sql
-- ✅ GOOD: Optional columns with defaults
ALTER TABLE public.flights 
ADD COLUMN takeoff_site_id UUID REFERENCES public.takeoff_sites(id),
ADD COLUMN max_altitude_m INTEGER DEFAULT NULL,
ADD COLUMN reviewed_by_instructor BOOLEAN DEFAULT FALSE;

-- ✅ GOOD: Add constraints after data population (if needed)
-- First add column, populate data, then add constraint
ALTER TABLE public.flights ADD COLUMN pilot_rating INTEGER;
-- ... populate data in application or separate script ...
-- ALTER TABLE public.flights ADD CONSTRAINT check_pilot_rating 
--   CHECK (pilot_rating >= 1 AND pilot_rating <= 5);
```

### Index Management

```sql
-- ✅ GOOD: Use CONCURRENTLY for production databases
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_flights_takeoff_site 
ON public.flights(takeoff_site_id) 
WHERE takeoff_site_id IS NOT NULL;

-- ✅ GOOD: Check index doesn't exist before creating
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes 
    WHERE indexname = 'idx_flights_complex_search'
  ) THEN
    CREATE INDEX CONCURRENTLY idx_flights_complex_search 
    ON public.flights(user_id, started_at DESC, duration_sec);
  END IF;
END $$;
```

### RLS Policy Updates

```sql
-- ✅ GOOD: Check policy exists before creating
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'takeoff_sites' 
    AND policyname = 'Users can view own takeoff sites'
  ) THEN
    CREATE POLICY "Users can view own takeoff sites" ON public.takeoff_sites
      FOR SELECT USING (auth.uid() = user_id);
  END IF;
END $$;
```

## Emergency Procedures

### Rolling Back a Migration

1. **Stop Application Traffic** (if possible)
2. **Apply Rollback Script**
   ```sql
   -- Execute rollback script from rollbacks/ folder
   \i rollbacks/002_rollback.sql
   ```
3. **Update Migration Tracking**
   ```sql
   DELETE FROM public.schema_migrations 
   WHERE version = '002_problematic_migration';
   ```
4. **Verify System State**
5. **Deploy Previous Application Version** (if needed)

### Fixing Failed Migrations

1. **Identify the Issue**
   - Check Supabase logs
   - Identify which statement failed
   
2. **Manual Cleanup**
   - Remove partially created objects
   - Reset to known good state
   
3. **Fix Migration Script**
   - Add missing IF EXISTS checks
   - Fix syntax or logic errors
   
4. **Re-apply Corrected Migration**

## Monitoring and Validation

After each migration:

1. **Check Application Health**
   - Monitor error rates
   - Check critical user flows
   - Verify data integrity

2. **Performance Monitoring**
   - Check query performance
   - Monitor index usage
   - Watch for lock contention

3. **Data Validation**
   ```sql
   -- Example validation queries
   SELECT COUNT(*) FROM public.flights WHERE created_at > NOW() - INTERVAL '1 day';
   SELECT COUNT(*) FROM public.pilots WHERE user_id IS NULL; -- Should be 0
   ```

## Migration Template

Use this template for new migrations:

```sql
-- Migration {sequence}: {Description}
-- Created: {date}
-- Description: {Detailed description of changes and rationale}

-- Pre-migration validation (optional)
-- DO $$ 
-- BEGIN
--   -- Add any pre-checks here
-- END $$;

-- Main migration code here
-- Remember to use IF NOT EXISTS, IF EXISTS where appropriate

-- Post-migration validation (optional)
-- DO $$ 
-- BEGIN
--   -- Add any post-checks here
--   -- RAISE EXCEPTION 'Migration validation failed' IF something is wrong
-- END $$;

-- Record migration completion
-- INSERT INTO public.schema_migrations (version) VALUES ('{sequence}_{name}');
```

---

**Last Updated**: March 2026  
**Next Migration Number**: 002