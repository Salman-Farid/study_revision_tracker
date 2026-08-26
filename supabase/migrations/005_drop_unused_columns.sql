-- Drop unused columns that are never written to
-- is_completed in topics: completion is determined by total_revisions >= 6
ALTER TABLE topics DROP COLUMN IF EXISTS is_completed;
-- completed_topics in subjects: never updated, always 0
ALTER TABLE subjects DROP COLUMN IF EXISTS completed_topics;
