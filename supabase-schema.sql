-- AcheFood 1.0 — esquema inicial para Supabase/PostgreSQL
-- Execute no SQL Editor do seu projeto Supabase.
create extension if not exists pgcrypto;

create table if not exists public.companies (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  legal_name text not null,
  trade_name text not null,
  cnpj text,
  phone text,
  address text,
  city text,
  business_type text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists companies_one_per_owner on public.companies(owner_id);

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  name text not null,
  brand text,
  category text not null,
  sale_unit text not null check (sale_unit in ('kg','box','un')),
  kg_per_piece numeric(10,3),
  kg_per_box numeric(10,3),
  barcode text,
  expiry_date date not null,
  photo_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists products_name_idx on public.products using gin (to_tsvector('simple', coalesce(name,'') || ' ' || coalesce(brand,'')));
create index if not exists products_company_idx on public.products(company_id);

create table if not exists public.wanted_requests (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references auth.users(id) on delete cascade,
  product text not null,
  brand text,
  city text,
  radius_km integer default 10,
  status text not null default 'open',
  created_at timestamptz not null default now()
);

create table if not exists public.opportunity_responses (
  id uuid primary key default gen_random_uuid(),
  wanted_id uuid not null references public.wanted_requests(id) on delete cascade,
  supplier_company_id uuid not null references public.companies(id) on delete cascade,
  product_id uuid references public.products(id) on delete set null,
  status text not null default 'sent',
  created_at timestamptz not null default now()
);

create table if not exists public.connections (
  id uuid primary key default gen_random_uuid(),
  buyer_id uuid references auth.users(id) on delete set null,
  supplier_company_id uuid references public.companies(id) on delete set null,
  wanted_id uuid references public.wanted_requests(id) on delete set null,
  created_at timestamptz not null default now()
);

alter table public.companies enable row level security;
alter table public.products enable row level security;
alter table public.wanted_requests enable row level security;
alter table public.opportunity_responses enable row level security;
alter table public.connections enable row level security;

-- Empresa: dono vê e edita apenas a própria empresa.
drop policy if exists companies_owner_select on public.companies;
create policy companies_owner_select on public.companies for select using (owner_id = auth.uid());
drop policy if exists companies_owner_insert on public.companies;
create policy companies_owner_insert on public.companies for insert with check (owner_id = auth.uid());
drop policy if exists companies_owner_update on public.companies;
create policy companies_owner_update on public.companies for update using (owner_id = auth.uid()) with check (owner_id = auth.uid());

-- Catálogo: dono administra seus produtos.
drop policy if exists products_owner_all on public.products;
create policy products_owner_all on public.products for all using (
  company_id in (select id from public.companies where owner_id = auth.uid())
) with check (
  company_id in (select id from public.companies where owner_id = auth.uid())
);

-- IMPORTANTE:
-- A busca pública deve ser feita por uma VIEW/FUNCTION que exponha somente
-- os campos permitidos (produto, marca, categoria, peso, validade e dados
-- públicos da empresa). Não conceda SELECT irrestrito à tabela companies.
-- O telefone/endereço/CNPJ podem ser controlados por plano/regra de acesso.

-- Demandas: usuário administra as próprias procuras.
drop policy if exists wanted_owner_all on public.wanted_requests;
create policy wanted_owner_all on public.wanted_requests for all using (requester_id = auth.uid()) with check (requester_id = auth.uid());

-- Respostas: fornecedor administra as respostas da própria empresa.
drop policy if exists opp_supplier_all on public.opportunity_responses;
create policy opp_supplier_all on public.opportunity_responses for all using (
  supplier_company_id in (select id from public.companies where owner_id = auth.uid())
) with check (
  supplier_company_id in (select id from public.companies where owner_id = auth.uid())
);

-- Conexões: participantes poderão consultar suas próprias conexões.
drop policy if exists connections_participant_select on public.connections;
create policy connections_participant_select on public.connections for select using (
  buyer_id = auth.uid() or supplier_company_id in (select id from public.companies where owner_id = auth.uid())
);

-- Storage:
-- Crie um bucket chamado "product-photos" como público para fotos de produto,
-- ou mantenha privado e entregue URLs assinadas via backend/function.
