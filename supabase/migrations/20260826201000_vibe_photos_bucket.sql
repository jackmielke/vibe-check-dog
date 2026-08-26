-- Public bucket for posted vibe photos. Public read is deliberate: the
-- leaderboard shows these images to everyone. Uploads are service-role only
-- (no insert/update/delete policy for anon), so every photo must pass through
-- submit-vibe, where the safety screen runs.

insert into storage.buckets (id, name, public)
values ('vibe-photos', 'vibe-photos', true)
on conflict (id) do update set public = excluded.public;

drop policy if exists "vibe photos are publicly readable" on storage.objects;
create policy "vibe photos are publicly readable"
    on storage.objects for select
    using (bucket_id = 'vibe-photos');
