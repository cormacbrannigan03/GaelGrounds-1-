-- 2022 Connacht SFC: this was the first season post-COVID that London and
-- New York both returned, and every pre-final match this project could
-- verify involved one of them (e.g. Mayo v London), so under the
-- established London/New York schema-gap policy nothing pre-final was
-- insertable. Only the final's score is added here.
update public.matches m
set home_score = '2-19', away_score = '2-16'
from public.competitions c
where m.competition_id = c.id and c.code = 'connacht_sfc' and m.season = 2022 and m.round = 'Final';
