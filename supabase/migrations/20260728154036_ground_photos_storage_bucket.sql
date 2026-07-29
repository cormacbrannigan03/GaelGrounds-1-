-- Public bucket for user-submitted ground photos. Photos themselves are
-- tracked via the existing (previously unused) public.user_visits.photo_urls
-- column -- adding a photo attaches it to the uploader's visit row for that
-- ground, same as the check-in flow already does for notes.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'ground-photos', 'ground-photos', true,
  8388608, -- 8 MiB
  array['image/jpeg', 'image/png', 'image/heic', 'image/webp']
)
on conflict (id) do nothing;

-- Object path shape: {user_id}/{ground_id}/{filename} -- users may only
-- write/delete within their own folder. Reads are public since the bucket
-- itself is public (matches how photo_urls is already publicly readable).
create policy "ground photos are publicly readable"
on storage.objects for select
to public
using (bucket_id = 'ground-photos');

create policy "users can upload their own ground photos"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'ground-photos'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "users can delete their own ground photos"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'ground-photos'
  and (storage.foldername(name))[1] = auth.uid()::text
);
