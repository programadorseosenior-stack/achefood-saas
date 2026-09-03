-- AcheFood SaaS V1 — foundation, multiempresa e autorização inicial.
-- Aplicar em ambiente de desenvolvimento antes de produção.
create extension if not exists pgcrypto;

create type public.profile_type as enum ('buyer','supplier','both');
create type public.member_role as enum ('owner','manager','buyer','seller','catalog_operator');
create type public.member_status as enum ('pending','active','suspended');
create type public.company_status as enum ('pending','active','suspended','blocked');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  first_name text,
  last_name text,
  phone text,
  profile_type public.profile_type,
  onboarding_completed boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.companies (
  id uuid primary key default gen_random_uuid(),
  legal_name text not null,
  trade_name text not null,
  cnpj text,
  phone text,
  cep text,
  city text,
  state char(2),
  latitude numeric(9,6),
  longitude numeric(9,6),
  service_radius_km integer check (service_radius_km between 1 and 1000),
  status public.company_status not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index companies_cnpj_unique on public.companies(regexp_replace(cnpj,'\D','','g')) where cnpj is not null;

create table public.company_members (
  company_id uuid not null references public.companies(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role public.member_role not null,
  status public.member_status not null default 'active',
  permissions jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (company_id,user_id)
);
create index company_members_user_idx on public.company_members(user_id) where status='active';

create table public.admin_members (
  user_id uuid primary key references auth.users(id) on delete restrict,
  role text not null check (role in ('admin','super_admin','support','moderator','financial')),
  status public.member_status not null default 'active',
  created_at timestamptz not null default now()
);

create table public.audit_logs (
  id bigint generated always as identity primary key,
  actor_id uuid references auth.users(id) on delete set null,
  action text not null,
  entity_type text not null,
  entity_id text,
  old_value jsonb,
  new_value jsonb,
  created_at timestamptz not null default now()
);

create or replace function public.set_updated_at() returns trigger language plpgsql set search_path='' as $$ begin new.updated_at=now(); return new; end $$;
create trigger profiles_updated before update on public.profiles for each row execute function public.set_updated_at();
create trigger companies_updated before update on public.companies for each row execute function public.set_updated_at();
create trigger company_members_updated before update on public.company_members for each row execute function public.set_updated_at();

create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path='' as $$
begin
  insert into public.profiles(id,first_name,last_name,profile_type)
  values(new.id,new.raw_user_meta_data->>'first_name',new.raw_user_meta_data->>'last_name',
    case when new.raw_user_meta_data->>'profile_type' in ('buyer','supplier','both') then (new.raw_user_meta_data->>'profile_type')::public.profile_type else null end)
  on conflict(id) do nothing;
  return new;
end $$;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();

create or replace function public.is_company_member(target_company uuid) returns boolean
language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.company_members cm where cm.company_id=target_company and cm.user_id=auth.uid() and cm.status='active')
$$;
create or replace function public.is_company_manager(target_company uuid) returns boolean
language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.company_members cm where cm.company_id=target_company and cm.user_id=auth.uid() and cm.status='active' and cm.role in ('owner','manager'))
$$;
revoke all on function public.is_company_member(uuid) from public;
revoke all on function public.is_company_manager(uuid) from public;
grant execute on function public.is_company_member(uuid),public.is_company_manager(uuid) to authenticated;

alter table public.profiles enable row level security;
alter table public.companies enable row level security;
alter table public.company_members enable row level security;
alter table public.admin_members enable row level security;
alter table public.audit_logs enable row level security;

create policy profiles_self_select on public.profiles for select to authenticated using(id=auth.uid());
create policy profiles_self_update on public.profiles for update to authenticated using(id=auth.uid()) with check(id=auth.uid());
create policy companies_member_select on public.companies for select to authenticated using(public.is_company_member(id));
create policy companies_manager_update on public.companies for update to authenticated using(public.is_company_manager(id)) with check(public.is_company_manager(id));
create policy memberships_member_select on public.company_members for select to authenticated using(public.is_company_member(company_id));
create policy memberships_owner_manage on public.company_members for all to authenticated using(public.is_company_manager(company_id)) with check(public.is_company_manager(company_id));

-- Admin membership and audit logs intentionally have no direct client policies.
-- Provision admins and execute privileged operations from trusted server-side code only.
