alter table public.push_subscriptions
  add column if not exists timezone_offset_minutes integer not null default 360;
