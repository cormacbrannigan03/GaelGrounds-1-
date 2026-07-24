with camogie_wins(county_name, year) as (
  values
    ('Cork',1940),('Cork',1970),('Cork',1983),('Cork',1993),('Cork',2008),('Cork',2014),('Cork',2017),
    ('Cork',2023),('Cork',2024),
    ('Kilkenny',2022),
    ('Wexford',2010),('Wexford',2011),('Wexford',2012),
    ('Galway',2025)
),
lgfa_wins(county_name, year) as (
  values
    ('Cork',2005),('Cork',2006),('Cork',2007),('Cork',2008),('Cork',2009),
    ('Cork',2011),('Cork',2012),('Cork',2013),('Cork',2014),('Cork',2015),('Cork',2016),
    ('Kerry',1982),('Kerry',1983),('Kerry',1984),('Kerry',1985),('Kerry',1986),('Kerry',1993),
    ('Dublin',2010),('Dublin',2017),('Dublin',2018),('Dublin',2019),('Dublin',2020),
    ('Waterford',1994),('Waterford',1995),
    ('Monaghan',1997),
    ('Mayo',1999),('Mayo',2000),
    ('Laois',2001)
)
insert into public.honours (team_type, county_team_id, honour_type, competition_name, year)
select 'county'::team_type, ct.id, 'all_ireland'::honour_type, 'All-Ireland Senior Camogie Championship', w.year
from camogie_wins w
join public.counties c on c.name = w.county_name
join public.county_teams ct on ct.county_id = c.id and ct.sport_code = 'camogie'
where not exists (
  select 1 from public.honours h
  where h.county_team_id = ct.id and h.honour_type = 'all_ireland'
    and h.competition_name = 'All-Ireland Senior Camogie Championship' and h.year = w.year
)
union all
select 'county'::team_type, ct.id, 'all_ireland'::honour_type, 'All-Ireland Senior Ladies'' Football Championship', w.year
from lgfa_wins w
join public.counties c on c.name = w.county_name
join public.county_teams ct on ct.county_id = c.id and ct.sport_code = 'ladies_football'
where not exists (
  select 1 from public.honours h
  where h.county_team_id = ct.id and h.honour_type = 'all_ireland'
    and h.competition_name = 'All-Ireland Senior Ladies'' Football Championship' and h.year = w.year
);
