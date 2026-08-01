alter table public.matches
  add column source_provider text not null default 'manual',
  add column source_ref text,
  add column source_synced_at timestamptz;

-- One row per (provider, external id) — this is the idempotency key every
-- provider adapter upserts against, so re-running a sync never duplicates
-- a match. Rows seeded by hand (the original demo data) keep source_ref
-- null and are simply never touched by the sync pipeline.
create unique index matches_source_provider_ref_key
  on public.matches (source_provider, source_ref)
  where source_ref is not null;

comment on column public.matches.source_provider is
  'Which data provider produced/owns this row: scorebeo, clubzap, csv, manual, or manual (hand-seeded, no external source).';
comment on column public.matches.source_ref is
  'Stable external identifier from the source provider, used for idempotent upserts. Null for hand-seeded rows.';
comment on column public.matches.source_synced_at is
  'When the sync pipeline last wrote/confirmed this row. Null for hand-seeded rows.';
