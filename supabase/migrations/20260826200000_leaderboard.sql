-- Vibe Check leaderboard. Reads are public; every write goes through an edge
-- function using the service role, so clients can never insert or mutate rows
-- directly. That is what keeps the safety screen in submit-vibe unskippable.
--
-- Written additively: an empty `leaderboard` table already existed on this
-- project, so this brings it up to the shape the app needs without assuming
-- what is or is not already there.

create table if not exists public.leaderboard (
    id         uuid primary key default gen_random_uuid(),
    created_at timestamptz not null default now()
);

alter table public.leaderboard add column if not exists name          text;
alter table public.leaderboard add column if not exists score         integer;
alter table public.leaderboard add column if not exists vibe_analysis text;
alter table public.leaderboard add column if not exists image_url     text;
-- Stable per-install/account owner so a poster can delete their own rows
-- without us storing anything that identifies a person.
alter table public.leaderboard add column if not exists owner_key     text;

create index if not exists leaderboard_score_idx   on public.leaderboard (score desc, created_at desc);
create index if not exists leaderboard_owner_idx   on public.leaderboard (owner_key);
create index if not exists leaderboard_created_idx on public.leaderboard (created_at desc);

alter table public.leaderboard enable row level security;

-- Public read only. No client-side insert/update/delete policies exist, so the
-- service role (edge functions) is the only writer.
drop policy if exists "leaderboard is publicly readable" on public.leaderboard;
create policy "leaderboard is publicly readable"
    on public.leaderboard for select
    using (true);
