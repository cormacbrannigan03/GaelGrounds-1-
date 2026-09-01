-- Referral program: every account gets a shareable code. Once 3 of the
-- people they referred have logged at least one match, the referrer earns
-- a free month of Premium -- repeating for every further group of 3, not
-- a one-off bonus.
alter table public.user_profiles
  add column referral_code text unique,
  add column referred_by_user_id uuid references public.user_profiles(id),
  add column referral_months_granted integer not null default 0;

create or replace function public.generate_referral_code()
returns text
language plpgsql
as $$
declare
  chars text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; -- no 0/O/1/I -- easy to misread
  code text;
  taken boolean;
begin
  loop
    code := '';
    for i in 1..6 loop
      code := code || substr(chars, floor(random() * length(chars))::int + 1, 1);
    end loop;
    select exists(select 1 from public.user_profiles where referral_code = code) into taken;
    exit when not taken;
  end loop;
  return code;
end;
$$;

update public.user_profiles set referral_code = public.generate_referral_code() where referral_code is null;

alter table public.user_profiles alter column referral_code set not null;

-- Extends the signup trigger from 20260805001600 to also assign a code to
-- the new account and resolve who referred it, from the same
-- raw_user_meta_data the client already passes display_name/
-- supported_county_id through.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  ref_code text := new.raw_user_meta_data ->> 'referral_code';
  referrer_id uuid;
begin
  if ref_code is not null and ref_code <> '' then
    select id into referrer_id from public.user_profiles where referral_code = upper(ref_code);
  end if;

  insert into public.user_profiles (id, display_name, supported_county_id, referral_code, referred_by_user_id)
  values (
    new.id,
    new.raw_user_meta_data ->> 'display_name',
    nullif(new.raw_user_meta_data ->> 'supported_county_id', '')::uuid,
    public.generate_referral_code(),
    referrer_id
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

-- Grants a free Premium month for every complete group of 3 referred
-- accounts that have logged at least one match. Recomputed from scratch
-- (not incremented) on every fire, which makes it naturally idempotent --
-- re-firing for a referred user's 2nd, 3rd... match is a harmless no-op
-- since months_earned won't have changed. Deliberately one-directional,
-- unlike achievement revocation (see the DELETE grant/policy fix on
-- user_achievements): once a month's been granted it's kept, even if a
-- referred user later deletes their only check-in -- this is a marketing
-- incentive, not a live-computed entitlement.
create or replace function public.check_referral_reward()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  referrer_id uuid;
  qualified_count integer;
  already_granted integer;
  months_earned integer;
  new_expiry timestamptz;
begin
  select referred_by_user_id into referrer_id from public.user_profiles where id = new.user_id;
  if referrer_id is null then
    return new;
  end if;

  select count(*) into qualified_count
  from public.user_profiles rp
  where rp.referred_by_user_id = referrer_id
    and exists (select 1 from public.user_match_attendance uma where uma.user_id = rp.id);

  months_earned := qualified_count / 3;

  select referral_months_granted into already_granted from public.user_profiles where id = referrer_id;

  if months_earned > already_granted then
    select greatest(coalesce(premium_expires_at, now()), now()) into new_expiry
    from public.user_profiles where id = referrer_id;

    update public.user_profiles
    set is_premium = true,
        premium_expires_at = new_expiry + ((months_earned - already_granted) * interval '1 month'),
        referral_months_granted = months_earned
    where id = referrer_id;
  end if;

  return new;
end;
$$;

create trigger on_match_attendance_check_referral
  after insert on public.user_match_attendance
  for each row
  execute function public.check_referral_reward();
