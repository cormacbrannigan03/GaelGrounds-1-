-- Six "counties" added later (exile/diaspora boards and one regional split
-- team) were missing primary/secondary colours. Researched per-team:
-- London GAA: green and white.
-- New York GAA: official colours "red, white and blue"; navy-dominant
--   jersey with red trim, so navy is used as primary here.
-- Lancashire GAA: blue and yellow.
-- Warwickshire GAA: black and white.
-- Fingal (Dublin's hurling-only exile-style board, est. 2008): purple
--   jersey (white trim), distinct from Dublin GAA's own blue.
-- South Down: a regional Down hurling team (est. 2007, competed in the
--   Lory Meagher Cup to 2011) drawn from south Co. Down excluding the Ards
--   peninsula; no distinct colours found, so it uses Down's own red/black.
update public.counties set primary_colour = '#009A44', secondary_colour = '#FFFFFF' where name = 'London';
update public.counties set primary_colour = '#002D72', secondary_colour = '#E4002B' where name = 'New York';
update public.counties set primary_colour = '#0033A0', secondary_colour = '#FFD700' where name = 'Lancashire';
update public.counties set primary_colour = '#000000', secondary_colour = '#FFFFFF' where name = 'Warwickshire';
update public.counties set primary_colour = '#702082', secondary_colour = '#FFFFFF' where name = 'Fingal';
update public.counties set primary_colour = '#D50032', secondary_colour = '#000000' where name = 'South Down';
