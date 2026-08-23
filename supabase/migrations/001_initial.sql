CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE subjects (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL, description TEXT, color_hex TEXT NOT NULL DEFAULT '#6C63FF',
  icon_code_point INTEGER NOT NULL DEFAULT 59553,
  total_topics INTEGER NOT NULL DEFAULT 0, completed_topics INTEGER NOT NULL DEFAULT 0,
  is_archived BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(), updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_subjects_user ON subjects(user_id);

CREATE TABLE topics (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  subject_id UUID NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
  name TEXT NOT NULL, notes TEXT, reference_answer TEXT, first_read_date TIMESTAMPTZ,
  is_completed BOOLEAN NOT NULL DEFAULT FALSE,
  mastery_level REAL NOT NULL DEFAULT 0.0, confidence REAL NOT NULL DEFAULT 0.0,
  total_revisions INTEGER NOT NULL DEFAULT 0, last_revised_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(), updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_topics_user ON topics(user_id);
CREATE INDEX idx_topics_subject ON topics(subject_id);

CREATE TABLE revision_schedules (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  topic_id UUID NOT NULL REFERENCES topics(id) ON DELETE CASCADE,
  subject_id UUID NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
  scheduled_date TIMESTAMPTZ NOT NULL, day_number INTEGER NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','completed','missed','rescheduled')),
  rescheduled_to UUID REFERENCES revision_schedules(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(), updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_schedules_user_date ON revision_schedules(user_id, scheduled_date);
CREATE INDEX idx_schedules_status ON revision_schedules(user_id, status);

CREATE TABLE revision_sessions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  topic_id UUID NOT NULL REFERENCES topics(id) ON DELETE CASCADE,
  schedule_id UUID REFERENCES revision_schedules(id),
  started_at TIMESTAMPTZ NOT NULL, ended_at TIMESTAMPTZ,
  duration_seconds INTEGER NOT NULL DEFAULT 0,
  recall_rating TEXT CHECK (recall_rating IN ('forgot','partial','good','perfect')),
  confidence REAL NOT NULL DEFAULT 0.0, notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_sessions_user ON revision_sessions(user_id);
CREATE INDEX idx_sessions_topic ON revision_sessions(topic_id);

ALTER TABLE subjects ENABLE ROW LEVEL SECURITY;
ALTER TABLE topics ENABLE ROW LEVEL SECURITY;
ALTER TABLE revision_schedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE revision_sessions ENABLE ROW LEVEL SECURITY;

CREATE POLICY subj_sel ON subjects FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY subj_ins ON subjects FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY subj_upd ON subjects FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY subj_del ON subjects FOR DELETE USING (auth.uid() = user_id);

CREATE POLICY top_sel ON topics FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY top_ins ON topics FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY top_upd ON topics FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY top_del ON topics FOR DELETE USING (auth.uid() = user_id);

CREATE POLICY sch_sel ON revision_schedules FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY sch_ins ON revision_schedules FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY sch_upd ON revision_schedules FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY sch_del ON revision_schedules FOR DELETE USING (auth.uid() = user_id);

CREATE POLICY ses_sel ON revision_sessions FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY ses_ins ON revision_sessions FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY ses_upd ON revision_sessions FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY ses_del ON revision_sessions FOR DELETE USING (auth.uid() = user_id);

CREATE OR REPLACE FUNCTION update_updated_at() RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END; $$ LANGUAGE plpgsql;

CREATE TRIGGER trg_subjects BEFORE UPDATE ON subjects FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_topics BEFORE UPDATE ON topics FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_schedules BEFORE UPDATE ON revision_schedules FOR EACH ROW EXECUTE FUNCTION update_updated_at();
