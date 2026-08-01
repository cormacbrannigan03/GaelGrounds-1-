-- 2021 Ulster SFC: as with 2022, every quarter-final/semi-final search hit
-- the same recurring contaminated batch of scores (Derry v Antrim,
-- Monaghan v Cavan, Armagh v Fermanagh, Down v Donegal) that has now
-- surfaced, unchanged, across three different query years (2021, 2022,
-- and originally flagged in 2024/2025 research) with April dates that
-- don't even match 2021's actual July championship window -- clearly
-- recycled/wrong content, not genuine 2021 results. Only the final is
-- recorded this season.
update public.matches m
set home_score = '0-16', away_score = '0-15', ground_id = g.id
from public.competitions c, public.grounds g
where m.competition_id = c.id and c.code = 'ulster_sfc' and m.season = 2021 and m.round = 'Final'
  and g.name = 'Croke Park';
