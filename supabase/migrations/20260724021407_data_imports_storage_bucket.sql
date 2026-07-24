insert into storage.buckets (id, name, public)
values ('data-imports', 'data-imports', false)
on conflict (id) do nothing;

-- Private bucket, no storage.objects policies added — only the Edge
-- Function's service_role client can read/write it. Uploading a CSV means
-- using the service_role key (Studio's Storage UI, or the API directly),
-- same access model as the rest of the ingestion pipeline.
