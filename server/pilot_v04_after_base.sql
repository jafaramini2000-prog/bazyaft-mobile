-- BAZYAFT pilot v0.4 additions.
-- Run ONLY inside a NEW, DEDICATED recycling Supabase project,
-- AFTER server/schema_for_new_recycling_project.sql.
-- NOT FOR SHAHREZA TREE SURVEY.
-- No actual payments, wallets, or credits are created here.

-- Pilot city; administration may expand this after reviewing service coverage.
insert into public.recycling_cities(name, active)
select 'شهرضا', true
where not exists (select 1 from public.recycling_cities where name = 'شهرضا');

-- Allow dispatchers/managers from the same city to view pickup addresses.
create policy "staff view pickup addresses in assigned city"
on public.recycling_addresses for select to authenticated
using (
  citizen_id = (select auth.uid())
  or exists (
    select 1 from public.recycling_staff s
    where s.user_id = (select auth.uid())
      and s.active = true and s.role in ('manager','dispatcher')
      and s.city_id = recycling_addresses.city_id
  )
);

-- Ensure minimal necessary API grants (table RLS remains authoritative).
grant usage on schema public to authenticated;
grant select on public.recycling_cities to authenticated;
grant select on public.recycling_staff to authenticated;
grant select,insert on public.recycling_addresses to authenticated;
grant select,insert on public.recycling_pickups to authenticated;
grant select,insert on public.recycling_pickup_materials to authenticated;
grant select on public.recycling_pickup_events to authenticated;

-- Single atomic RPC: address, pickup, material rows succeed or fail together.
-- Invoker security means every insert remains subject to the existing RLS policies.
create or replace function public.recycling_submit_pickup(
  p_city_id uuid,
  p_address text,
  p_title text,
  p_details text,
  p_materials text[],
  p_amount text,
  p_note text,
  p_idempotency_key uuid
)
returns uuid
language plpgsql security invoker set search_path = ''
as $$
declare
  v_user uuid := (select auth.uid());
  v_address_id uuid;
  v_pickup_id uuid;
begin
  if v_user is null then
    raise exception 'Authentication required';
  end if;
  if trim(coalesce(p_address,'')) = '' or length(p_address) > 500 then
    raise exception 'Invalid address';
  end if;
  if p_amount not in ('one','two_or_three','more_than_three') then
    raise exception 'Invalid estimated bags';
  end if;
  if p_idempotency_key is null then
    raise exception 'Missing idempotency key';
  end if;
  if coalesce(array_length(p_materials,1),0) < 1
     or coalesce(array_length(p_materials,1),0) > 5
     or exists (select 1 from unnest(p_materials) m
                where m is null or m not in ('plastic','paper','metal','glass','other')) then
    raise exception 'Invalid materials';
  end if;
  if not exists (select 1 from public.recycling_cities where id=p_city_id and active=true) then
    raise exception 'City is not enabled';
  end if;

  select id into v_pickup_id
  from public.recycling_pickups
  where citizen_id = v_user and idempotency_key = p_idempotency_key;
  if v_pickup_id is not null then return v_pickup_id; end if;

  insert into public.recycling_addresses (citizen_id,city_id,title,street_address,unit_details)
  values (v_user,p_city_id,coalesce(nullif(trim(p_title),''),'خانه'),p_address,p_details)
  returning id into v_address_id;

  insert into public.recycling_pickups
    (citizen_id,address_id,city_id,idempotency_key,status,estimated_bags,citizen_note)
  values (v_user,v_address_id,p_city_id,p_idempotency_key,'submitted',p_amount,p_note)
  returning id into v_pickup_id;

  insert into public.recycling_pickup_materials(pickup_id,material_type)
  select v_pickup_id, m from (select distinct unnest(p_materials) as m) q;

  return v_pickup_id;
end;
$$;
revoke all on function public.recycling_submit_pickup(uuid,text,text,text,text[],text,text,uuid) from public, anon;
grant execute on function public.recycling_submit_pickup(uuid,text,text,text,text[],text,text,uuid) to authenticated;

-- Initial event is created on server, never from the citizen application.
create or replace function recycling_internal.log_new_pickup()
returns trigger language plpgsql security definer set search_path=''
as $$
begin
  insert into public.recycling_pickup_events(pickup_id,old_status,new_status,actor_id,note)
  values (new.id,null,new.status,new.citizen_id,'ثبت اولیه روی سرور');
  return new;
end; $$;
revoke all on function recycling_internal.log_new_pickup() from public, anon;
create trigger recycling_pickup_created_event
  after insert on public.recycling_pickups
  for each row execute function recycling_internal.log_new_pickup();

-- Status transitions are made by trusted backend logic, never by a citizen UPDATE.
-- Pilot 0.4 permits the initial manager approval; routing and driver actions are future work.
create schema if not exists recycling_internal;
revoke all on schema recycling_internal from public;
grant usage on schema recycling_internal to authenticated;

create or replace function recycling_internal.apply_transition(
  p_pickup_id uuid,
  p_new_status text
) returns uuid
language plpgsql security definer set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
  v_city uuid;
  v_old text;
begin
  if v_actor is null then raise exception 'Authentication required'; end if;
  select city_id,status into v_city,v_old
  from public.recycling_pickups
  where id=p_pickup_id for update;
  if not found then raise exception 'Pickup not found'; end if;
  if not exists (
     select 1 from public.recycling_staff
     where user_id=v_actor and city_id=v_city and active=true
       and role in ('manager','dispatcher')
  ) then
    raise exception 'Not authorized for this city';
  end if;
  if not (
    (v_old='submitted' and p_new_status='approved')
  ) then
    raise exception 'Invalid pilot status transition';
  end if;
  update public.recycling_pickups
  set status=p_new_status,updated_at=now()
  where id=p_pickup_id;
  insert into public.recycling_pickup_events
    (pickup_id,old_status,new_status,actor_id,note)
  values(p_pickup_id,v_old,p_new_status,v_actor,'تغییر مرحله در پایلوت ۰.۴');
  return p_pickup_id;
end;
$$;
revoke all on function recycling_internal.apply_transition(uuid,text) from public, anon;
grant execute on function recycling_internal.apply_transition(uuid,text) to authenticated;

-- This public wrapper is INVOKER (not definer). Protected function is in an
-- unexposed schema, with explicit staff/city/transition validation.
create or replace function public.recycling_update_pickup_status(
  p_pickup_id uuid,
  p_new_status text
) returns uuid
language sql security invoker set search_path=''
as $$ select recycling_internal.apply_transition(p_pickup_id,p_new_status); $$;
revoke all on function public.recycling_update_pickup_status(uuid,text) from public, anon;
grant execute on function public.recycling_update_pickup_status(uuid,text) to authenticated;

-- Enable live updates. Supabase Realtime must also be enabled in project settings.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'recycling_pickups'
  ) then
    execute 'alter publication supabase_realtime add table public.recycling_pickups';
  end if;
end $$;

-- Managers are NEVER assigned from app-side user metadata.
-- Find verified Auth user ID in Supabase Auth UI and enter it via SQL Editor.
-- Example (replace placeholders ONLY on a dedicated recycling project):
-- insert into public.recycling_staff(user_id,city_id,role,active)
-- select '<MANAGER_AUTH_USER_UUID>'::uuid,id,'manager',true
-- from public.recycling_cities where name='شهرضا';
