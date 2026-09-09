-- Per-user blocking, plus a durable record of every moderation action.
--
-- App Store guideline 1.2 requires three things of an app with user-generated
-- content: a way to flag content, a way to block an abusive *user* (not just
-- hide one post), and evidence that the developer acts on reports within 24
-- hours. Report-only was what got the sibling app rejected in July, so the
-- missing piece here is blocking by poster.
--
-- The problem: owner_key is the poster's private handle and deliberately never
-- leaves the server, so a client has nothing stable to block. poster_id below
-- is a one-way pseudonym derived from it - stable across that poster's rows,
-- useless anywhere else, and safe to hand to clients.

-- Defensive: is_hidden is read by leaderboard-api but was applied directly to
-- the remote project before this repo existed, so it has no migration of its
-- own. Declare it here so a fresh environment matches production.
alter table public.leaderboard add column if not exists is_hidden boolean not null default false;

-- Generated + stored, so it is maintained automatically and every existing row
-- is backfilled by the ALTER itself. md5 is immutable, which generated columns
-- require; the suffix keeps the digest from matching a bare md5(owner_key)
-- computed anywhere else.
alter table public.leaderboard
    add column if not exists poster_id text
    generated always as (md5(coalesce(owner_key, '') || '::vibe-check-poster')) stored;

create index if not exists leaderboard_poster_idx on public.leaderboard (poster_id);

-- Who has blocked whom. blocker_key is the blocker's own owner_key, which only
-- ever travels from that device; poster_id is the pseudonym above.
create table if not exists public.blocked_posters (
    id          uuid primary key default gen_random_uuid(),
    blocker_key text        not null,
    poster_id   text        not null,
    created_at  timestamptz not null default now(),
    unique (blocker_key, poster_id)
);

create index if not exists blocked_posters_blocker_idx on public.blocked_posters (blocker_key);

-- The developer-facing audit trail. Every block and every report lands here, so
-- "we act on reports within 24 hours" is a claim that can actually be checked
-- rather than an assertion about an inbox.
create table if not exists public.moderation_events (
    id           uuid primary key default gen_random_uuid(),
    kind         text        not null check (kind in ('block', 'unblock', 'report')),
    poster_id    text,
    entry_id     uuid,
    reporter_key text,
    note         text,
    created_at   timestamptz not null default now(),
    resolved_at  timestamptz
);

create index if not exists moderation_events_open_idx
    on public.moderation_events (created_at desc)
    where resolved_at is null;

create index if not exists moderation_events_entry_idx on public.moderation_events (entry_id);

-- Same posture as leaderboard: RLS on, and no client-side policies at all. The
-- edge functions hold the service role and are the only writers, which is what
-- stops a client from blocking on someone else's behalf or clearing its own
-- report history.
alter table public.blocked_posters   enable row level security;
alter table public.moderation_events enable row level security;
