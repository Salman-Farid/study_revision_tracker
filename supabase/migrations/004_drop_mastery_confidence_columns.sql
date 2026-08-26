-- Drop mastery_level and confidence columns from topics table
-- These fields are no longer needed for the simplified revision workflow
ALTER TABLE topics DROP COLUMN IF EXISTS mastery_level;
ALTER TABLE topics DROP COLUMN IF EXISTS confidence;
