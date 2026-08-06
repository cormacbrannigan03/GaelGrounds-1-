-- Three new "ground completionist" achievement families, layered on top of
-- the existing county_home_match ones:
--   county_grounds_complete   -- visited every ground within one county
--   province_grounds_complete -- visited every ground across a province
--   country_grounds_complete  -- visited every ground in the whole app
-- Evaluated client-side in AchievementsService.evaluate() by comparing the
-- user's distinct visited ground_ids against the full ground count for the
-- relevant county/province/country. Every county has at least one ground,
-- so every county gets a definition -- no empty-set edge case to exclude.

insert into public.achievement_definitions (code, title, description, icon, rule_type, rule_params)
select
  'county_grounds_complete_' || lower(regexp_replace(c.name, '[^a-zA-Z0-9]+', '_', 'g')),
  c.name || ' Complete',
  'Visit every ground in ' || c.name || '.',
  'checkmark.seal.fill',
  'county_grounds_complete',
  jsonb_build_object('county_id', c.id)
from public.counties c
where not exists (
  select 1 from public.achievement_definitions ad
  where ad.rule_type = 'county_grounds_complete'
    and (ad.rule_params->>'county_id')::uuid = c.id
);

insert into public.achievement_definitions (code, title, description, icon, rule_type, rule_params)
select
  'province_grounds_complete_' || lower(p.name),
  p.name || ' Complete',
  'Visit every ground across ' || p.name || '.',
  'map.fill',
  'province_grounds_complete',
  jsonb_build_object('province', p.name)
from (values ('Ulster'), ('Munster'), ('Leinster'), ('Connacht')) as p(name)
where not exists (
  select 1 from public.achievement_definitions ad
  where ad.rule_type = 'province_grounds_complete' and ad.rule_params->>'province' = p.name
);

insert into public.achievement_definitions (code, title, description, icon, rule_type, rule_params)
select
  'country_grounds_complete',
  'Ireland Complete',
  'Visit every ground in the app, across every county.',
  'globe.europe.africa.fill',
  'country_grounds_complete',
  '{}'::jsonb
where not exists (
  select 1 from public.achievement_definitions where rule_type = 'country_grounds_complete'
);
