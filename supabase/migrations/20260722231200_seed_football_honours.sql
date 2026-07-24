with wins(county_name, year) as (
  values
    -- Kerry (39 titles; 2009/2014/2022/2025 already recorded)
    ('Kerry',1903),('Kerry',1904),('Kerry',1909),('Kerry',1913),('Kerry',1914),('Kerry',1924),('Kerry',1926),
    ('Kerry',1929),('Kerry',1930),('Kerry',1931),('Kerry',1932),('Kerry',1937),('Kerry',1939),('Kerry',1940),
    ('Kerry',1941),('Kerry',1946),('Kerry',1953),('Kerry',1955),('Kerry',1959),('Kerry',1962),('Kerry',1969),
    ('Kerry',1970),('Kerry',1975),('Kerry',1978),('Kerry',1979),('Kerry',1980),('Kerry',1981),('Kerry',1984),
    ('Kerry',1985),('Kerry',1986),('Kerry',1997),('Kerry',2000),('Kerry',2004),('Kerry',2006),('Kerry',2007),
    -- Dublin (31 titles; 2023 already recorded)
    ('Dublin',1891),('Dublin',1892),('Dublin',1894),('Dublin',1897),('Dublin',1898),('Dublin',1899),('Dublin',1901),
    ('Dublin',1902),('Dublin',1906),('Dublin',1907),('Dublin',1908),('Dublin',1921),('Dublin',1922),('Dublin',1923),
    ('Dublin',1942),('Dublin',1958),('Dublin',1963),('Dublin',1974),('Dublin',1976),('Dublin',1977),('Dublin',1983),
    ('Dublin',1995),('Dublin',2011),('Dublin',2013),('Dublin',2015),('Dublin',2016),('Dublin',2017),('Dublin',2018),
    ('Dublin',2019),('Dublin',2020),
    -- Galway
    ('Galway',1925),('Galway',1934),('Galway',1938),('Galway',1956),('Galway',1964),('Galway',1965),('Galway',1966),
    ('Galway',1998),('Galway',2001),
    -- Cork
    ('Cork',1890),('Cork',1911),('Cork',1945),('Cork',1973),('Cork',1989),('Cork',1990),('Cork',2010),
    -- Meath
    ('Meath',1949),('Meath',1954),('Meath',1967),('Meath',1987),('Meath',1988),('Meath',1996),('Meath',1999),
    -- Down
    ('Down',1960),('Down',1961),('Down',1968),('Down',1991),('Down',1994),
    -- Cavan
    ('Cavan',1933),('Cavan',1935),('Cavan',1947),('Cavan',1948),('Cavan',1952),
    -- Mayo
    ('Mayo',1936),('Mayo',1950),('Mayo',1951),
    -- Tyrone (2021 already recorded)
    ('Tyrone',2003),('Tyrone',2005),('Tyrone',2008),
    -- Donegal
    ('Donegal',1992),('Donegal',2012),
    -- Armagh (2024 already recorded)
    ('Armagh',2002),
    -- Offaly
    ('Offaly',1971),('Offaly',1972),('Offaly',1982),
    -- Louth
    ('Louth',1910),('Louth',1912),('Louth',1957),
    -- Wexford
    ('Wexford',1893),('Wexford',1915),('Wexford',1916),('Wexford',1917),('Wexford',1918),
    -- Roscommon
    ('Roscommon',1943),('Roscommon',1944),
    -- Derry
    ('Derry',1993),
    -- Kildare
    ('Kildare',1905),('Kildare',1919),('Kildare',1927),('Kildare',1928),
    -- Limerick (the very first final)
    ('Limerick',1887)
)
insert into public.honours (team_type, county_team_id, honour_type, competition_name, year)
select 'county', ct.id, 'all_ireland', 'All-Ireland Senior Football Championship', w.year
from wins w
join public.counties c on c.name = w.county_name
join public.county_teams ct on ct.county_id = c.id and ct.sport_code = 'gaelic_football'
where not exists (
  select 1 from public.honours h
  where h.county_team_id = ct.id and h.honour_type = 'all_ireland'
    and h.competition_name = 'All-Ireland Senior Football Championship' and h.year = w.year
);
