create table if not exists public.food_nutrition_cache (
  query text primary key,
  payload jsonb not null,
  updated_at timestamptz not null default now()
);

alter table public.food_nutrition_cache enable row level security;
