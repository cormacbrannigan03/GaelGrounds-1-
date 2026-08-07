-- Public bucket for user profile photos, mirroring the ground-photos bucket
-- (20260728154036_ground_photos_storage_bucket.sql) exactly. The URL itself
-- is tracked via the existing (previously unused) public.user_profiles.avatar_url
-- column.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'avatars', 'avatars', true,
  8388608, -- 8 MiB
  array['image/jpeg', 'image/png', 'image/heic', 'image/webp']
)
on conflict (id) do nothing;

-- Object path shape: {user_id}/avatar.jpg -- one photo per user, uploaded
-- with upsert so re-uploading replaces the existing file in place rather
-- than accumulating orphaned objects. Users may only write/delete within
-- their own folder. Reads are public since the bucket itself is public.
create policy "avatars are publicly readable"
on storage.objects for select
to public
using (bucket_id = 'avatars');

create policy "users can upload their own avatar"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "users can replace their own avatar"
on storage.objects for update
to authenticated
using (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = auth.uid()::text
)
with check (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "users can delete their own avatar"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = auth.uid()::text
);
