# Run This Query in Supabase SQL Editor

Open your Supabase Dashboard → SQL Editor → New Query → Paste the command below → Run.

```sql
ALTER TABLE class_routines ADD COLUMN IF NOT EXISTS location TEXT;
```

This adds the `location` column to your existing `class_routines` table. Safe to run multiple times — will not fail if the column already exists.
