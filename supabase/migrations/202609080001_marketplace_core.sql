-- AcheFood SaaS V1 - marketplace operacional multiempresa.
-- Requer as migrations foundation, commercial e dashboard_metrics.
begin;

create type public.catalog_item_status as enum ('draft','active','inactive','archived');
create type public.opportunity_status as enum ('draft','open','closed','cancelled');
create type public.quote_status as enum ('draft','submitted','accepted','rejected','withdrawn','expired');
create type public.connection_status as enum ('pending','accepted','rejected','blocked');

create table public.categories (
  id uuid primary key default gen_random_uuid(),
  parent_id uuid references public.categories(id) on delete set null,
  name text not null check (length(trim(name)) between 2 and 100),
  slug text not null unique check (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (parent_id is null or parent_id <> id)
);

create table public.products (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  category_id uuid references public.categories(id) on delete set null,
  name text not null check (length(trim(name)) between 2 and 180),
  slug text not null check (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  description text not null default '' check (length(description) <= 10000),
  sku text check (sku is null or length(trim(sku)) between 1 and 80),
  unit text not null default 'un' check (length(trim(unit)) between 1 and 30),
  price numeric(14,2) check (price is null or price >= 0),
  currency text not null default 'BRL' check (currency = 'BRL'),
  min_order_quantity numeric(14,3) not null default 1 check (min_order_quantity > 0),
  status public.catalog_item_status not null default 'draft',
  image_url text check (image_url is null or length(image_url) <= 2048),
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata) = 'object'),
  created_by uuid not null references auth.users(id) on delete restrict default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (company_id, slug)
);
create index products_company_status_idx on public.products(company_id,status,updated_at desc);
create index products_category_status_idx on public.products(category_id,status) where category_id is not null;
create index products_search_idx on public.products using gin
  (to_tsvector('simple', coalesce(name,'') || ' ' || coalesce(description,'') || ' ' || coalesce(sku,'')));

create table public.opportunities (
  id uuid primary key default gen_random_uuid(),
  buyer_company_id uuid not null references public.companies(id) on delete cascade,
  category_id uuid references public.categories(id) on delete set null,
  title text not null check (length(trim(title)) between 3 and 180),
  description text not null default '' check (length(description) <= 10000),
  status public.opportunity_status not null default 'draft',
  delivery_city text check (delivery_city is null or length(trim(delivery_city)) between 2 and 120),
  delivery_state char(2) check (delivery_state is null or delivery_state ~ '^[A-Z]{2}$'),
  closes_at timestamptz,
  published_at timestamptz,
  created_by uuid not null references auth.users(id) on delete restrict default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (status <> 'open' or published_at is not null),
  check (closes_at is null or closes_at > created_at)
);
create index opportunities_buyer_status_idx on public.opportunities(buyer_company_id,status,created_at desc);
create index opportunities_open_idx on public.opportunities(category_id,closes_at) where status='open';
create index opportunities_search_idx on public.opportunities using gin
  (to_tsvector('simple', coalesce(title,'') || ' ' || coalesce(description,'')));

create table public.opportunity_items (
  id uuid primary key default gen_random_uuid(),
  opportunity_id uuid not null references public.opportunities(id) on delete cascade,
  product_name text not null check (length(trim(product_name)) between 2 and 180),
  description text not null default '' check (length(description) <= 4000),
  quantity numeric(14,3) not null check (quantity > 0),
  unit text not null default 'un' check (length(trim(unit)) between 1 and 30),
  position integer not null default 0 check (position >= 0),
  unique (opportunity_id, position)
);
create index opportunity_items_opportunity_idx on public.opportunity_items(opportunity_id);

create table public.quotes (
  id uuid primary key default gen_random_uuid(),
  opportunity_id uuid not null references public.opportunities(id) on delete cascade,
  supplier_company_id uuid not null references public.companies(id) on delete cascade,
  status public.quote_status not null default 'draft',
  notes text not null default '' check (length(notes) <= 10000),
  currency text not null default 'BRL' check (currency = 'BRL'),
  subtotal numeric(14,2) not null default 0 check (subtotal >= 0),
  shipping_amount numeric(14,2) not null default 0 check (shipping_amount >= 0),
  total_amount numeric(14,2) generated always as (subtotal + shipping_amount) stored,
  valid_until timestamptz,
  submitted_at timestamptz,
  created_by uuid not null references auth.users(id) on delete restrict default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (opportunity_id, supplier_company_id),
  check (status not in ('submitted','accepted','rejected','expired') or submitted_at is not null),
  check (valid_until is null or valid_until > created_at)
);
create index quotes_supplier_status_idx on public.quotes(supplier_company_id,status,created_at desc);
create index quotes_opportunity_status_idx on public.quotes(opportunity_id,status,created_at desc);

create table public.quote_items (
  id uuid primary key default gen_random_uuid(),
  quote_id uuid not null references public.quotes(id) on delete cascade,
  opportunity_item_id uuid references public.opportunity_items(id) on delete set null,
  description text not null check (length(trim(description)) between 2 and 1000),
  quantity numeric(14,3) not null check (quantity > 0),
  unit text not null default 'un' check (length(trim(unit)) between 1 and 30),
  unit_price numeric(14,2) not null check (unit_price >= 0),
  total_price numeric(14,2) generated always as (round(quantity * unit_price, 2)) stored,
  position integer not null default 0 check (position >= 0),
  unique (quote_id, position)
);
create index quote_items_quote_idx on public.quote_items(quote_id);

create table public.connections (
  id uuid primary key default gen_random_uuid(),
  buyer_company_id uuid not null references public.companies(id) on delete cascade,
  supplier_company_id uuid not null references public.companies(id) on delete cascade,
  initiated_by_company_id uuid not null references public.companies(id) on delete restrict,
  status public.connection_status not null default 'pending',
  created_by uuid not null references auth.users(id) on delete restrict default auth.uid(),
  responded_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (buyer_company_id,supplier_company_id),
  check (buyer_company_id <> supplier_company_id),
  check (initiated_by_company_id in (buyer_company_id,supplier_company_id)),
  check (status = 'pending' or responded_at is not null)
);
create index connections_buyer_status_idx on public.connections(buyer_company_id,status,updated_at desc);
create index connections_supplier_status_idx on public.connections(supplier_company_id,status,updated_at desc);

create table public.conversations (
  id uuid primary key default gen_random_uuid(),
  connection_id uuid not null unique references public.connections(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_company_id uuid not null references public.companies(id) on delete restrict,
  sender_user_id uuid not null references auth.users(id) on delete restrict default auth.uid(),
  body text not null check (length(trim(body)) between 1 and 8000),
  read_at timestamptz,
  created_at timestamptz not null default now()
);
create index messages_conversation_created_idx on public.messages(conversation_id,created_at desc);
create index messages_unread_idx on public.messages(conversation_id,created_at) where read_at is null;

create trigger categories_updated before update on public.categories for each row execute function public.set_updated_at();
create trigger products_updated before update on public.products for each row execute function public.set_updated_at();
create trigger opportunities_updated before update on public.opportunities for each row execute function public.set_updated_at();
create trigger quotes_updated before update on public.quotes for each row execute function public.set_updated_at();
create trigger connections_updated before update on public.connections for each row execute function public.set_updated_at();
create trigger conversations_updated before update on public.conversations for each row execute function public.set_updated_at();

-- Helpers evitam RLS recursiva e centralizam os papeis operacionais.
create or replace function public.can_manage_catalog(target_company uuid) returns boolean
language sql stable security definer set search_path='' as $$
  select public.is_super_admin() or exists (
    select 1 from public.company_members cm
    where cm.company_id=target_company and cm.user_id=auth.uid() and cm.status='active'
      and cm.role in ('owner','manager','seller','catalog_operator')
  )
$$;
create or replace function public.can_manage_opportunities(target_company uuid) returns boolean
language sql stable security definer set search_path='' as $$
  select public.is_super_admin() or exists (
    select 1 from public.company_members cm
    where cm.company_id=target_company and cm.user_id=auth.uid() and cm.status='active'
      and cm.role in ('owner','manager','buyer')
  )
$$;
create or replace function public.can_access_opportunity(target_opportunity uuid) returns boolean
language sql stable security definer set search_path='' as $$
  select public.is_super_admin() or exists (
    select 1 from public.opportunities o
    where o.id=target_opportunity
      and (o.status='open' or public.is_company_member(o.buyer_company_id))
  )
$$;
create or replace function public.can_access_quote(target_quote uuid) returns boolean
language sql stable security definer set search_path='' as $$
  select public.is_super_admin() or exists (
    select 1 from public.quotes q join public.opportunities o on o.id=q.opportunity_id
    where q.id=target_quote
      and (public.is_company_member(q.supplier_company_id) or public.is_company_member(o.buyer_company_id))
  )
$$;
create or replace function public.can_access_connection(target_connection uuid) returns boolean
language sql stable security definer set search_path='' as $$
  select public.is_super_admin() or exists (
    select 1 from public.connections c where c.id=target_connection
      and (public.is_company_member(c.buyer_company_id) or public.is_company_member(c.supplier_company_id))
  )
$$;

revoke all on function public.can_manage_catalog(uuid), public.can_manage_opportunities(uuid),
  public.can_access_opportunity(uuid), public.can_access_quote(uuid), public.can_access_connection(uuid) from public;
grant execute on function public.can_manage_catalog(uuid), public.can_manage_opportunities(uuid),
  public.can_access_opportunity(uuid), public.can_access_quote(uuid), public.can_access_connection(uuid) to authenticated;

alter table public.categories enable row level security;
alter table public.products enable row level security;
alter table public.opportunities enable row level security;
alter table public.opportunity_items enable row level security;
alter table public.quotes enable row level security;
alter table public.quote_items enable row level security;
alter table public.connections enable row level security;
alter table public.conversations enable row level security;
alter table public.messages enable row level security;

create policy categories_read on public.categories for select to authenticated
  using (is_active or public.is_super_admin());
create policy categories_admin_manage on public.categories for all to authenticated
  using (public.is_super_admin()) with check (public.is_super_admin());

create policy products_read on public.products for select to authenticated
  using (status='active' or public.is_company_member(company_id) or public.is_super_admin());
create policy products_insert on public.products for insert to authenticated
  with check (public.can_manage_catalog(company_id) and created_by=auth.uid());
create policy products_update on public.products for update to authenticated
  using (public.can_manage_catalog(company_id)) with check (public.can_manage_catalog(company_id));
create policy products_delete on public.products for delete to authenticated
  using (public.can_manage_catalog(company_id));

create policy opportunities_read on public.opportunities for select to authenticated
  using (public.can_access_opportunity(id));
create policy opportunities_insert on public.opportunities for insert to authenticated
  with check (public.can_manage_opportunities(buyer_company_id) and created_by=auth.uid());
create policy opportunities_update on public.opportunities for update to authenticated
  using (public.can_manage_opportunities(buyer_company_id)) with check (public.can_manage_opportunities(buyer_company_id));
create policy opportunities_delete on public.opportunities for delete to authenticated
  using (public.can_manage_opportunities(buyer_company_id) and status='draft');

create policy opportunity_items_read on public.opportunity_items for select to authenticated
  using (public.can_access_opportunity(opportunity_id));
create policy opportunity_items_insert on public.opportunity_items for insert to authenticated
  with check (exists (select 1 from public.opportunities o where o.id=opportunity_id and public.can_manage_opportunities(o.buyer_company_id) and o.status='draft'));
create policy opportunity_items_update on public.opportunity_items for update to authenticated
  using (exists (select 1 from public.opportunities o where o.id=opportunity_id and public.can_manage_opportunities(o.buyer_company_id) and o.status='draft'))
  with check (exists (select 1 from public.opportunities o where o.id=opportunity_id and public.can_manage_opportunities(o.buyer_company_id) and o.status='draft'));
create policy opportunity_items_delete on public.opportunity_items for delete to authenticated
  using (exists (select 1 from public.opportunities o where o.id=opportunity_id and public.can_manage_opportunities(o.buyer_company_id) and o.status='draft'));

create policy quotes_read on public.quotes for select to authenticated using (public.can_access_quote(id));
create policy quotes_insert on public.quotes for insert to authenticated
  with check (public.can_manage_catalog(supplier_company_id) and created_by=auth.uid()
    and exists (select 1 from public.opportunities o where o.id=opportunity_id and o.status='open'
      and (o.closes_at is null or o.closes_at>now()) and o.buyer_company_id<>supplier_company_id));
create policy quotes_update_supplier on public.quotes for update to authenticated
  using (public.can_manage_catalog(supplier_company_id) and status='draft')
  with check (public.can_manage_catalog(supplier_company_id) and status='draft');
create policy quotes_delete_draft on public.quotes for delete to authenticated
  using (public.can_manage_catalog(supplier_company_id) and status='draft');

create policy quote_items_read on public.quote_items for select to authenticated using (public.can_access_quote(quote_id));
create policy quote_items_insert on public.quote_items for insert to authenticated
  with check (exists (select 1 from public.quotes q where q.id=quote_id and q.status='draft' and public.can_manage_catalog(q.supplier_company_id)));
create policy quote_items_update on public.quote_items for update to authenticated
  using (exists (select 1 from public.quotes q where q.id=quote_id and q.status='draft' and public.can_manage_catalog(q.supplier_company_id)))
  with check (exists (select 1 from public.quotes q where q.id=quote_id and q.status='draft' and public.can_manage_catalog(q.supplier_company_id)));
create policy quote_items_delete on public.quote_items for delete to authenticated
  using (exists (select 1 from public.quotes q where q.id=quote_id and q.status='draft' and public.can_manage_catalog(q.supplier_company_id)));

create policy connections_read on public.connections for select to authenticated using (public.can_access_connection(id));
create policy connections_insert on public.connections for insert to authenticated
  with check (public.is_company_member(initiated_by_company_id) and created_by=auth.uid()
    and initiated_by_company_id in (buyer_company_id,supplier_company_id));

create policy conversations_read on public.conversations for select to authenticated
  using (public.can_access_connection(connection_id));
create policy conversations_insert on public.conversations for insert to authenticated
  with check (public.can_access_connection(connection_id)
    and exists (select 1 from public.connections c where c.id=connection_id and c.status='accepted'));

create policy messages_read on public.messages for select to authenticated
  using (exists (select 1 from public.conversations c where c.id=conversation_id and public.can_access_connection(c.connection_id)));
create policy messages_insert on public.messages for insert to authenticated
  with check (sender_user_id=auth.uid() and public.is_company_member(sender_company_id)
    and exists (select 1 from public.conversations cv join public.connections c on c.id=cv.connection_id
      where cv.id=conversation_id and c.status='accepted'
        and sender_company_id in (c.buyer_company_id,c.supplier_company_id)));
-- Compradores decidem uma cotacao sem receber permissao para alterar valores ou autoria.
create or replace function public.respond_to_quote(target_quote uuid, decision public.quote_status) returns void
language plpgsql security definer set search_path='' as $$
declare q public.quotes; buyer_company uuid;
begin
  if decision not in ('accepted','rejected') then raise exception 'Decisao invalida'; end if;
  select q0.* into q
  from public.quotes q0
  where q0.id=target_quote for update;
  if q.id is null then raise exception 'Cotacao nao encontrada'; end if;
  select o.buyer_company_id into buyer_company
  from public.opportunities o where o.id=q.opportunity_id;
  if not (public.can_manage_opportunities(buyer_company) or public.is_super_admin()) then
    raise exception 'Acesso negado' using errcode='42501';
  end if;
  if q.status<>'submitted' or (q.valid_until is not null and q.valid_until<=now()) then
    raise exception 'Cotacao indisponivel para decisao';
  end if;
  update public.quotes set status=decision where id=target_quote;
  if decision='accepted' then
    update public.quotes set status='rejected'
    where opportunity_id=q.opportunity_id and id<>target_quote and status='submitted';
    update public.opportunities set status='closed' where id=q.opportunity_id;
  end if;
end $$;
revoke all on function public.respond_to_quote(uuid,public.quote_status) from public;
grant execute on function public.respond_to_quote(uuid,public.quote_status) to authenticated;

-- Transicoes protegidas: clientes nao recebem UPDATE direto nos registros sensiveis.
create or replace function public.submit_quote(target_quote uuid) returns void
language plpgsql security definer set search_path='' as $$
declare q public.quotes; calculated numeric(14,2); opportunity_open boolean;
begin
  select * into q from public.quotes where id=target_quote for update;
  if q.id is null then raise exception 'Cotacao nao encontrada'; end if;
  if not (public.can_manage_catalog(q.supplier_company_id) or public.is_super_admin()) then
    raise exception 'Acesso negado' using errcode='42501';
  end if;
  if q.status<>'draft' then raise exception 'Somente cotacoes em rascunho podem ser enviadas'; end if;
  select (o.status='open' and (o.closes_at is null or o.closes_at>now())) into opportunity_open
  from public.opportunities o where o.id=q.opportunity_id;
  if not coalesce(opportunity_open,false) then raise exception 'Oportunidade encerrada'; end if;
  select coalesce(sum(qi.total_price),0) into calculated from public.quote_items qi where qi.quote_id=target_quote;
  if calculated<=0 then raise exception 'Inclua ao menos um item com valor positivo'; end if;
  update public.quotes set subtotal=calculated,status='submitted',submitted_at=now() where id=target_quote;
end $$;

create or replace function public.respond_to_connection(target_connection uuid, decision public.connection_status) returns void
language plpgsql security definer set search_path='' as $$
declare c public.connections; responding_company uuid;
begin
  if decision not in ('accepted','rejected','blocked') then raise exception 'Decisao invalida'; end if;
  select * into c from public.connections where id=target_connection for update;
  if c.id is null then raise exception 'Conexao nao encontrada'; end if;
  responding_company:=case when c.initiated_by_company_id=c.buyer_company_id then c.supplier_company_id else c.buyer_company_id end;
  if not (public.is_company_member(responding_company) or public.is_super_admin()) then
    raise exception 'Acesso negado' using errcode='42501';
  end if;
  if c.status<>'pending' then raise exception 'Conexao ja respondida'; end if;
  update public.connections set status=decision,responded_at=now() where id=target_connection;
  if decision='accepted' then
    insert into public.conversations(connection_id) values(target_connection)
    on conflict(connection_id) do nothing;
  end if;
end $$;

create or replace function public.create_and_submit_quote(
  target_opportunity uuid,
  supplier_company uuid,
  item_description text,
  item_quantity numeric,
  item_unit text,
  item_unit_price numeric,
  quote_notes text default '',
  quote_valid_until timestamptz default null
) returns uuid
language plpgsql security definer set search_path='' as $$
declare result_id uuid; target_buyer uuid;
begin
  if auth.uid() is null or not public.can_manage_catalog(supplier_company) then
    raise exception 'Acesso negado' using errcode='42501';
  end if;
  if length(trim(item_description))<2 or item_quantity<=0 or item_unit_price<0 then
    raise exception 'Dados da cotacao invalidos';
  end if;
  select buyer_company_id into target_buyer from public.opportunities
  where id=target_opportunity and status='open' and (closes_at is null or closes_at>now()) for update;
  if target_buyer is null or target_buyer=supplier_company then raise exception 'Oportunidade indisponivel'; end if;
  insert into public.quotes(opportunity_id,supplier_company_id,status,notes,subtotal,valid_until,submitted_at)
  values(target_opportunity,supplier_company,'submitted',coalesce(quote_notes,''),round(item_quantity*item_unit_price,2),quote_valid_until,now())
  returning id into result_id;
  insert into public.quote_items(quote_id,description,quantity,unit,unit_price)
  values(result_id,item_description,item_quantity,item_unit,item_unit_price);
  return result_id;
end $$;

create or replace function public.mark_conversation_read(target_conversation uuid) returns integer
language plpgsql security definer set search_path='' as $$
declare affected integer;
begin
  if not exists (
    select 1 from public.conversations cv join public.connections c on c.id=cv.connection_id
    where cv.id=target_conversation and c.status='accepted' and public.can_access_connection(c.id)
  ) then raise exception 'Acesso negado' using errcode='42501'; end if;
  update public.messages set read_at=coalesce(read_at,now())
  where conversation_id=target_conversation and sender_user_id<>auth.uid() and read_at is null;
  get diagnostics affected = row_count;
  return affected;
end $$;

revoke all on function public.submit_quote(uuid), public.respond_to_connection(uuid,public.connection_status),
  public.create_and_submit_quote(uuid,uuid,text,numeric,text,numeric,text,timestamptz),
  public.mark_conversation_read(uuid) from public;
grant execute on function public.submit_quote(uuid), public.respond_to_connection(uuid,public.connection_status),
  public.create_and_submit_quote(uuid,uuid,text,numeric,text,numeric,text,timestamptz),
  public.mark_conversation_read(uuid) to authenticated;

revoke all on public.categories,public.products,public.opportunities,public.opportunity_items,
  public.quotes,public.quote_items,public.connections,public.conversations,public.messages from anon,authenticated;
grant select,insert,update,delete on public.categories,public.products,public.opportunities,public.opportunity_items,
  public.quotes,public.quote_items to authenticated;
grant select,insert on public.connections,public.conversations,public.messages to authenticated;
grant all on public.categories,public.products,public.opportunities,public.opportunity_items,
  public.quotes,public.quote_items,public.connections,public.conversations,public.messages to service_role;

commit;
