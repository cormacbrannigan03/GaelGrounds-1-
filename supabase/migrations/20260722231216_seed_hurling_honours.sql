with wins(county_name, year) as (
  values
    -- Kilkenny — recent/well-documented era (36 titles total; full pre-1990 list not confidently reconstructable here)
    ('Kilkenny',1992),('Kilkenny',1993),('Kilkenny',2000),('Kilkenny',2002),('Kilkenny',2003),('Kilkenny',2006),
    ('Kilkenny',2007),('Kilkenny',2008),('Kilkenny',2009),('Kilkenny',2011),('Kilkenny',2014),
    -- Cork — well-documented eras (30 titles total; earlier decades not confidently reconstructable here)
    ('Cork',1941),('Cork',1942),('Cork',1943),('Cork',1944),('Cork',1976),('Cork',1977),('Cork',1978),
    ('Cork',1984),('Cork',1986),('Cork',1990),('Cork',1999),('Cork',2004),('Cork',2005),
    -- Tipperary — well-documented eras (28 titles total; earlier decades not confidently reconstructable here)
    ('Tipperary',1958),('Tipperary',1961),('Tipperary',1962),('Tipperary',1964),('Tipperary',1965),
    ('Tipperary',1971),('Tipperary',1989),('Tipperary',1991),('Tipperary',2001),('Tipperary',2010),
    ('Tipperary',2016),
    -- Limerick (2021/2022/2023 already recorded)
    ('Limerick',1897),('Limerick',1918),('Limerick',1921),('Limerick',1934),('Limerick',1936),('Limerick',1940),
    ('Limerick',1973),('Limerick',2018),('Limerick',2020),
    -- Wexford
    ('Wexford',1910),('Wexford',1955),('Wexford',1956),('Wexford',1960),('Wexford',1968),('Wexford',1996),
    -- Dublin
    ('Dublin',1889),('Dublin',1917),('Dublin',1920),('Dublin',1924),('Dublin',1927),('Dublin',1938),
    -- Clare (2024 already recorded)
    ('Clare',1914),('Clare',1995),('Clare',1997),('Clare',2013),
    -- Galway
    ('Galway',1923),('Galway',1980),('Galway',1987),('Galway',1988),('Galway',2017),
    -- Offaly
    ('Offaly',1981),('Offaly',1985),('Offaly',1994),('Offaly',1998),
    -- Waterford
    ('Waterford',1948),('Waterford',1959),
    -- Laois
    ('Laois',1915)
)
insert into public.honours (team_type, county_team_id, honour_type, competition_name, year)
select 'county', ct.id, 'all_ireland', 'All-Ireland Senior Hurling Championship', w.year
from wins w
join public.counties c on c.name = w.county_name
join public.county_teams ct on ct.county_id = c.id and ct.sport_code = 'hurling'
where not exists (
  select 1 from public.honours h
  where h.county_team_id = ct.id and h.honour_type = 'all_ireland'
    and h.competition_name = 'All-Ireland Senior Hurling Championship' and h.year = w.year
);
