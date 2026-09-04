-- Add location column to class_routines (single string field like "UB43A")
-- Safe to run multiple times — will not fail if column already exists
DO $$ BEGIN
  ALTER TABLE class_routines ADD COLUMN location TEXT;
EXCEPTION WHEN duplicate_column THEN NULL;
END $$;

-- Ensure floor column exists too (added in 006)
DO $$ BEGIN
  ALTER TABLE class_routines ADD COLUMN floor TEXT;
EXCEPTION WHEN duplicate_column THEN NULL;
END $$;
