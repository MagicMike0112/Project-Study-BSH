-- supabase/leaderboard.sql
-- Friends relationship + weekly leaderboard RPC

-- 1) Friends relationship table
create table if not exists public.user_friends (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  friend_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending','accepted','blocked')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint user_friends_no_self check (user_id <> friend_id)
);

create unique index if not exists user_friends_unique_pair
  on public.user_friends (least(user_id, friend_id), greatest(user_id, friend_id));

create index if not exists user_friends_user_id_idx on public.user_friends (user_id);
create index if not exists user_friends_friend_id_idx on public.user_friends (friend_id);

alter table public.user_friends enable row level security;

-- Read: only participants can see the relationship
create policy if not exists user_friends_select
on public.user_friends for select
using (auth.uid() = user_id or auth.uid() = friend_id);

-- Insert: only requester can create
create policy if not exists user_friends_insert
on public.user_friends for insert
with check (auth.uid() = user_id);

-- Update: requester or recipient can update status
create policy if not exists user_friends_update
on public.user_friends for update
using (auth.uid() = user_id or auth.uid() = friend_id)
with check (auth.uid() = user_id or auth.uid() = friend_id);

-- Delete: requester or recipient can remove
create policy if not exists user_friends_delete
on public.user_friends for delete
using (auth.uid() = user_id or auth.uid() = friend_id);

-- Keep updated_at fresh
create or replace function public.touch_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists user_friends_touch on public.user_friends;
create trigger user_friends_touch
before update on public.user_friends
for each row execute function public.touch_updated_at();

-- 2) Weekly leaderboard RPC (world top N)
-- Returns aggregated points (co2_saved) for eaten + fedToPet within time range.
create or replace function public.weekly_leaderboard(
  start_ts timestamptz,
  end_ts timestamptz,
  limit_count int default 1000
)
returns table (
  user_id uuid,
  points numeric
)
language sql
stable
security definer
set search_path = public
as $$
  select
    u.id as user_id,
    coalesce(sum(e.co2_saved), 0) as points
  from public.user_profiles u
  left join public.impact_events e
    on e.user_id = u.id
   and e.created_at >= start_ts
   and e.created_at < end_ts
   and e.type in ('eaten', 'fedToPet', 'trash')
  group by u.id
  order by points desc
  limit limit_count;
$$;
