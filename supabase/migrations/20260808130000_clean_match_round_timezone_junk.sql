-- A handful of matches.round values picked up a stray kickoff-time/timezone
-- fragment during sync (e.g. "14:00 IWT (UTC±00:00) | Semi-final" instead of
-- just "Semi-final"), and a few lost their round label entirely (just
-- "13:00 BST (UTC+1)" with nothing after it). This pollutes the Results tab
-- search (which matches against round text) with junk and hides the actual
-- round name. Strips everything up to and including the trailing ")" plus
-- an optional "|" separator, keeping only the real round label; rows with
-- nothing left after stripping go to NULL rather than an empty string.
update public.matches
set round = nullif(trim(regexp_replace(round, '^.*\)\s*\|?\s*', '')), '')
where round ~ 'IST|IWT|BST|UTC';
