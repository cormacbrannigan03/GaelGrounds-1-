-- Internal ingestion tables are owned by backend functions and service-role
-- jobs. RLS already denies clients; revoke default grants as a second layer.
revoke all on table public.data_providers from anon, authenticated;
revoke all on table public.data_sync_runs from anon, authenticated;
revoke all on table public.manual_match_submissions from anon, authenticated;
revoke all on table public.provider_competition_aliases from anon, authenticated;
revoke all on table public.provider_ground_aliases from anon, authenticated;
revoke all on table public.provider_team_aliases from anon, authenticated;

-- Pin the immutable score helper's search path.
alter function public.gaa_score_total(text) set search_path = '';

-- These extension-owned helpers are not part of the GaelGrounds client API.
-- Leave PostGIS installed, but prevent public Data API discovery/calls.
revoke all on table public.spatial_ref_sys from anon, authenticated;
revoke all on table public.raster_columns from anon, authenticated;
revoke all on table public.raster_overviews from anon, authenticated;
revoke execute on function public.pgaudit_ddl_command_end() from public, anon, authenticated;
revoke execute on function public.pgaudit_sql_drop() from public, anon, authenticated;
revoke execute on function public.st_estimatedextent(text, text) from public, anon, authenticated;
revoke execute on function public.st_estimatedextent(text, text, text) from public, anon, authenticated;
revoke execute on function public.st_estimatedextent(text, text, text, boolean) from public, anon, authenticated;
