-- "Road Traveller" achievements: the away/neutral-venue counterpart to the
-- existing county_home_match ("home games") achievements, mirrored 1:1 for
-- every (county, sport) pair that already has a home-match definition.
-- Tiering (bronze/silver/gold at 10/25/50) is computed client-side exactly
-- like county_home_match, via AchievementTier.forHomeMatchCount reused on
-- a road-game count instead of a home-game count.
insert into public.achievement_definitions (code, title, description, icon, rule_type, rule_params)
select
  'county_away_match_' || lower(regexp_replace(c.name, '[^a-zA-Z0-9]+', '_', 'g')) || '_' || (ad.rule_params ->> 'sport_code'),
  coalesce(c.nickname, c.name) || ' — Road Traveller (' ||
    case ad.rule_params ->> 'sport_code' when 'gaelic_football' then 'Football' when 'hurling' then 'Hurling' else ad.rule_params ->> 'sport_code' end
  || ')',
  'Attend an away or neutral-venue ' ||
    case ad.rule_params ->> 'sport_code' when 'gaelic_football' then 'football' when 'hurling' then 'hurling' else ad.rule_params ->> 'sport_code' end
  || ' match involving ' || c.name || '.',
  'car.fill',
  'county_away_match',
  jsonb_build_object('county_id', c.id, 'sport_code', ad.rule_params ->> 'sport_code')
from public.achievement_definitions ad
join public.counties c on c.id = (ad.rule_params ->> 'county_id')::uuid
where ad.rule_type = 'county_home_match'
and not exists (
  select 1 from public.achievement_definitions ad2
  where ad2.rule_type = 'county_away_match'
    and (ad2.rule_params ->> 'county_id')::uuid = c.id
    and ad2.rule_params ->> 'sport_code' = ad.rule_params ->> 'sport_code'
);
