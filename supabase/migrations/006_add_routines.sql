-- Class routines: which day, what subject, what time, what building/room
-- Pure schedule tracker — nothing to do with study data or topics
CREATE TABLE class_routines (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  subject_name TEXT NOT NULL,
  start_time TIMESTAMPTZ NOT NULL,
  duration_minutes INTEGER NOT NULL DEFAULT 60,
  dates TEXT[] NOT NULL DEFAULT '{}',
  building TEXT,
  floor TEXT,
  room TEXT,
  recurring BOOLEAN NOT NULL DEFAULT FALSE,
  recurring_days INTEGER[] DEFAULT '{}',
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_class_routines_user ON class_routines(user_id);
CREATE INDEX idx_class_routines_date ON class_routines(user_id, start_time);

-- Daily routines: a snapshot of the user's daily study plan
CREATE TABLE daily_routines (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  date DATE NOT NULL,
  items JSONB NOT NULL DEFAULT '[]',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_daily_routines_user_date ON daily_routines(user_id, date);

ALTER TABLE class_routines ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_routines ENABLE ROW LEVEL SECURITY;

CREATE POLICY cr_sel ON class_routines FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY cr_ins ON class_routines FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY cr_upd ON class_routines FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY cr_del ON class_routines FOR DELETE USING (auth.uid() = user_id);

CREATE POLICY dr_sel ON daily_routines FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY dr_ins ON daily_routines FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY dr_upd ON daily_routines FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY dr_del ON daily_routines FOR DELETE USING (auth.uid() = user_id);

CREATE TRIGGER trg_class_routines_updated_at
  BEFORE UPDATE ON class_routines
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_daily_routines_updated_at
  BEFORE UPDATE ON daily_routines
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Add floor column if table already exists (for existing databases)
DO $$ BEGIN
  ALTER TABLE class_routines ADD COLUMN floor TEXT;
EXCEPTION WHEN duplicate_column THEN NULL;
END $$;
