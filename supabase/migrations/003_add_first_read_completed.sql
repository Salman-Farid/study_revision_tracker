-- Add first_read_completed column to topics table
-- This tracks whether the user has completed the first read of a topic.
-- Separate from is_completed (which tracks overall topic mastery/completion).
ALTER TABLE topics ADD COLUMN first_read_completed BOOLEAN NOT NULL DEFAULT FALSE;

-- Create index for filtering topics by first_read status
CREATE INDEX idx_topics_first_read ON topics(user_id, first_read_completed);
