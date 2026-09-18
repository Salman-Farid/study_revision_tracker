-- Subtopics: one-level hierarchy under topics (Subject → Topic → Subtopic)
-- parent_topic_id IS NULL → top-level topic (existing rows unchanged)

alter table public.topics
  add column if not exists parent_topic_id uuid references public.topics(id) on delete cascade;

create index if not exists topics_parent_topic_id_idx
  on public.topics (parent_topic_id);

create index if not exists topics_user_subject_parent_idx
  on public.topics (user_id, subject_id, parent_topic_id);
