-- Production Web Push for daily-routine block reminders.
create table if not exists public.push_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  endpoint text not null unique,
  p256dh text not null,
  auth text not null,
  timezone text not null default 'Asia/Dhaka',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.push_send_log (
  id uuid primary key default gen_random_uuid(),
  endpoint text not null,
  block_key text not null,
  sent_at timestamptz not null default now(),
  unique (endpoint, block_key)
);

create index if not exists push_subscriptions_user_idx
  on public.push_subscriptions (user_id);
create index if not exists push_send_log_lookup_idx
  on public.push_send_log (endpoint, block_key);
