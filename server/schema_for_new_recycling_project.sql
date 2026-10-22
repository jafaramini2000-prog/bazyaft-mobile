-- BAZYAFT SERVICE BACKEND / DESIGN STARTER
-- IMPORTANT: Run ONLY on a newly created, dedicated recycling Supabase project.
-- Do NOT run on the existing Shahreza Tree Survey database.
-- This schema intentionally does not activate payments or actual wallet credit.

create extension if not exists pgcrypto;

create table public.recycling_cities (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  active boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.recycling_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  created_at timestamptz not null default now()
);

create table public.recycling_staff (
  user_id uuid primary key references auth.users(id) on delete cascade,
  city_id uuid not null references public.recycling_cities(id),
  role text not null check (role in ('manager','dispatcher','driver')),
  active boolean not null default true
);

create table public.recycling_addresses (
  id uuid primary key default gen_random_uuid(),
  citizen_id uuid not null references auth.users(id) on delete cascade,
  city_id uuid not null references public.recycling_cities(id),
  title text not null default 'خانه',
  street_address text not null,
  unit_details text,
  lat double precision,
  lon double precision,
  created_at timestamptz not null default now(),
  constraint valid_lat check (lat is null or lat between -90 and 90),
  constraint valid_lon check (lon is null or lon between -180 and 180)
);

create table public.recycling_pickups (
  id uuid primary key default gen_random_uuid(),
  citizen_id uuid not null references auth.users(id) on delete cascade,
  address_id uuid not null references public.recycling_addresses(id),
  city_id uuid not null references public.recycling_cities(id),
  idempotency_key uuid not null,
  status text not null default 'submitted' check (status in (
    'submitted','approved','scheduled','assigned','en_route','collected','weighed','credited','cancelled')),
  estimated_bags text check (estimated_bags in ('one','two_or_three','more_than_three')),
  citizen_note text,
  scheduled_start timestamptz,
  scheduled_end timestamptz,
  assigned_driver_id uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (citizen_id, idempotency_key),
  check (scheduled_end is null or scheduled_start is null or scheduled_end > scheduled_start)
);

create index on public.recycling_pickups (city_id,status,scheduled_start);
create index on public.recycling_pickups (citizen_id,created_at desc);
create index on public.recycling_pickups (assigned_driver_id,scheduled_start);

create table public.recycling_pickup_materials (
  pickup_id uuid not null references public.recycling_pickups(id) on delete cascade,
  material_type text not null check (material_type in ('plastic','paper','metal','glass','other','electronics')),
  expected_weight_kg numeric(9,2),
  actual_weight_kg numeric(9,2),
  primary key (pickup_id,material_type),
  check (expected_weight_kg is null or expected_weight_kg >= 0),
  check (actual_weight_kg is null or actual_weight_kg >= 0)
);

-- Server-generated append-only status audit; clients have no INSERT/UPDATE/DELETE access.
create table public.recycling_pickup_events (
  id bigint generated always as identity primary key,
  pickup_id uuid not null references public.recycling_pickups(id) on delete cascade,
  old_status text,
  new_status text not null,
  actor_id uuid references auth.users(id),
  note text,
  created_at timestamptz not null default now()
);
create index on public.recycling_pickup_events (pickup_id,id);

-- Merchant directory only: payment, ledger, settlement and QR redemption will
-- need separate transaction-safe backend work and verified commercial contracts.
create table public.recycling_merchants (
  id uuid primary key default gen_random_uuid(),
  display_name text not null,
  category text not null check (category in ('restaurant','grocery','shopping','services')),
  city_id uuid not null references public.recycling_cities(id),
  active boolean not null default false,
  created_at timestamptz not null default now()
);

-- RLS: client can never declare itself a staff member.
alter table public.recycling_cities enable row level security;
alter table public.recycling_profiles enable row level security;
alter table public.recycling_staff enable row level security;
alter table public.recycling_addresses enable row level security;
alter table public.recycling_pickups enable row level security;
alter table public.recycling_pickup_materials enable row level security;
alter table public.recycling_pickup_events enable row level security;
alter table public.recycling_merchants enable row level security;

create policy "cities visible to signed-in users" on public.recycling_cities
  for select to authenticated using (active = true);

create policy "profile owner read" on public.recycling_profiles
  for select to authenticated using (user_id = (select auth.uid()));
create policy "profile owner create" on public.recycling_profiles
  for insert to authenticated with check (user_id = (select auth.uid()));
create policy "profile owner update" on public.recycling_profiles
  for update to authenticated using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy "staff view own role" on public.recycling_staff
  for select to authenticated using (user_id = (select auth.uid()));

create policy "address owner read" on public.recycling_addresses
  for select to authenticated using (citizen_id = (select auth.uid()));
create policy "address owner insert" on public.recycling_addresses
  for insert to authenticated with check (citizen_id = (select auth.uid()));
create policy "address owner update" on public.recycling_addresses
  for update to authenticated using (citizen_id = (select auth.uid()))
  with check (citizen_id = (select auth.uid()));

create policy "citizen or authorized team view pickups" on public.recycling_pickups
  for select to authenticated using (
    citizen_id = (select auth.uid())
    or assigned_driver_id = (select auth.uid())
    or exists (
      select 1 from public.recycling_staff st
       where st.user_id = (select auth.uid()) and st.active = true
         and st.city_id = recycling_pickups.city_id
         and st.role in ('manager','dispatcher')
    )
  );

create policy "citizen submit own pickup at own address" on public.recycling_pickups
  for insert to authenticated with check (
    citizen_id = (select auth.uid()) and status = 'submitted'
    and assigned_driver_id is null
    and scheduled_start is null and scheduled_end is null
    and exists (
      select 1 from public.recycling_addresses a
      where a.id = address_id and a.citizen_id = (select auth.uid()) and a.city_id = recycling_pickups.city_id
    )
  );

create policy "view materials for visible pickups" on public.recycling_pickup_materials
  for select to authenticated using (
    exists (select 1 from public.recycling_pickups p where p.id = pickup_id)
  );
create policy "add own pickup materials before dispatch" on public.recycling_pickup_materials
  for insert to authenticated with check (
    exists (select 1 from public.recycling_pickups p
      where p.id = pickup_id and p.citizen_id = (select auth.uid()) and p.status = 'submitted')
    and material_type <> 'electronics'
  );

create policy "view events for visible pickups" on public.recycling_pickup_events
  for select to authenticated using (
    exists (select 1 from public.recycling_pickups p where p.id = pickup_id)
  );

create policy "browse approved local merchants" on public.recycling_merchants
  for select to authenticated using (active = true);

-- Data API grants and RLS both needed. NO client UPDATE/DELETE on pickup,
-- staff, status events, actual weights or future finance ledger.
grant select on public.recycling_cities to authenticated;
grant select,insert,update on public.recycling_profiles to authenticated;
grant select on public.recycling_staff to authenticated;
grant select,insert,update on public.recycling_addresses to authenticated;
grant select,insert on public.recycling_pickups to authenticated;
grant select,insert on public.recycling_pickup_materials to authenticated;
grant select on public.recycling_pickup_events to authenticated;
grant select on public.recycling_merchants to authenticated;

-- Allow realtime request status tracking only after reviewing actual policies:
-- alter publication supabase_realtime add table public.recycling_pickups;
-- alter publication supabase_realtime add table public.recycling_pickup_events;
