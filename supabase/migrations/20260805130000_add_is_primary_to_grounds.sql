-- Marks each county's main/headquarters ground so the Grounds map
-- (GroundsMapView.swift) can render primary grounds larger with a name
-- label, and the Grounds tab's grid can show "notable" grounds first
-- (GroundsView.swift filters on this column).
--
-- NOTE: this column already existed live with this exact data when found
-- (2026-08-05) -- added ad hoc, outside this migration history, by
-- whoever built the grounds map feature (GroundsView.swift/
-- GroundsMapView.swift, both referencing `ground.isPrimary`, landed in a
-- commit that never touched the Ground.swift model to match -- a genuine
-- compile-time gap, fixed alongside this file by adding `isPrimary: Bool`
-- to Ground.swift). Captured here, matching the pattern already
-- established for other schema found live without a migration file
-- (sync-public-fixtures, the friendships/user_personal_matches ad-hoc
-- tables), so a fresh project setup reproduces the same state.
alter table public.grounds
  add column if not exists is_primary boolean not null default false;

update public.grounds set is_primary = true
where name in (
  'Athletic Grounds', 'Aughrim County Ground', 'Breffni Park', 'Brewster Park',
  'Celtic Park', 'Corrigan Park', 'Croke Park', 'Cullen Park',
  'Cusack Park (Ennis)', 'Cusack Park (Mullingar)', 'Dr Hyde Park',
  'Fitzgerald Stadium', 'Gaelic Grounds', 'Gaelic Park', 'Healy Park',
  'Lawless Memorial Park', 'MacCumhaill Park', 'MacHale Park',
  'Markievicz Park', 'McGovern Park', 'Nowlan Park', 'O''Connor Park',
  'O''Moore Park', 'Old Bedians', 'Páirc Esler', 'Páirc Mhuire',
  'Páirc na hÉireann', 'Páirc Niamh, Ballela', 'Páirc Seán Mac Diarmada',
  'Páirc Tailteann', 'Páirc Uí Chaoimh', 'Pearse Park', 'Pearse Stadium',
  'Semple Stadium', 'St Conleth''s Park', 'St Tiernach''s Park',
  'Walsh Park', 'Wexford Park'
);
