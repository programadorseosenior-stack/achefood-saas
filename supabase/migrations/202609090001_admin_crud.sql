-- AcheFood SaaS V1 - contratos administrativos seguros para CRUD e relatorios.
-- Requer: foundation, commercial, auth_roles_first_access e marketplace_core.
begin;

-- Os indices abaixo sustentam filtros e ordenacoes usados pelo painel administrativo.
create index if not exists companies_status_updated_idx
  on public.companies(status, updated_at desc);
create index if not exists profiles_status_created_idx
  on public.profiles(status, created_at desc);
create index if not exists profiles_email_lower_idx
  on public.profiles(lower(email)) where email is not null;
create index if not exists products_status_updated_idx
  on public.products(status, updated_at desc);
create index if not exists audit_logs_entity_created_idx
  on public.audit_logs(entity_type, entity_id, created_at desc);
create index if not exists audit_logs_actor_created_idx
  on public.audit_logs(actor_id, created_at desc) where actor_id is not null;

-- Toda RPC administrativa chama esta funcao. Sem sessao ou sem super_admin ativo,
-- a operacao falha antes de ler ou modificar qualquer dado.
create or replace function public.require_super_admin() returns uuid
language plpgsql stable security definer set search_path='' as $$
declare uid uuid := auth.uid();
begin
  if uid is null or not exists (
    select 1 from public.admin_members am
    where am.user_id=uid and am.role='super_admin' and am.status='active'
  ) then
    raise exception 'Acesso administrativo negado' using errcode='42501';
  end if;
  return uid;
end $$;

create or replace function public.write_admin_audit(
  audit_action text,
  audit_entity_type text,
  audit_entity_id text,
  audit_old_value jsonb default null,
  audit_new_value jsonb default null
) returns void
language plpgsql volatile security definer set search_path='' as $$
declare uid uuid := public.require_super_admin();
begin
  if nullif(trim(audit_action),'') is null or nullif(trim(audit_entity_type),'') is null then
    raise exception 'Evento de auditoria invalido' using errcode='22023';
  end if;
  insert into public.audit_logs(actor_id,action,entity_type,entity_id,old_value,new_value)
  values(uid,audit_action,audit_entity_type,audit_entity_id,audit_old_value,audit_new_value);
end $$;

-- Empresas -------------------------------------------------------------------
create or replace function public.admin_list_companies(
  search_term text default null,
  status_filter public.company_status default null,
  page_limit integer default 50,
  page_offset integer default 0
) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
  perform public.require_super_admin();
  if page_limit not between 1 and 200 or page_offset < 0 then
    raise exception 'Paginacao invalida' using errcode='22023';
  end if;
  with filtered as (
    select c.*
    from public.companies c
    where (status_filter is null or c.status=status_filter)
      and (nullif(trim(search_term),'') is null
        or c.trade_name ilike '%'||trim(search_term)||'%'
        or c.legal_name ilike '%'||trim(search_term)||'%'
        or coalesce(c.cnpj,'') ilike '%'||trim(search_term)||'%')
  ), rows_data as (
    select f.id,f.legal_name,f.trade_name,f.cnpj,f.phone,f.city,f.state,f.status,
      f.created_at,f.updated_at,
      (select count(*) from public.company_members cm where cm.company_id=f.id and cm.status='active') as active_members,
      (select count(*) from public.products p where p.company_id=f.id and p.status<>'archived') as products,
      s.status as subscription_status,pn.name as plan_name,pn.slug as plan_slug
    from filtered f
    left join public.subscriptions s on s.company_id=f.id
    left join public.plans pn on pn.id=s.plan_id
    order by f.updated_at desc,f.id
    limit page_limit offset page_offset
  )
  select jsonb_build_object(
    'items',coalesce((select jsonb_agg(to_jsonb(r) order by r.updated_at desc,r.id) from rows_data r),'[]'::jsonb),
    'total',(select count(*) from filtered), 'limit',page_limit, 'offset',page_offset
  ) into result;
  return result;
end $$;

create or replace function public.admin_save_company(target_company uuid, company_data jsonb) returns uuid
language plpgsql volatile security definer set search_path='' as $$
declare uid uuid := public.require_super_admin(); old_row public.companies; saved public.companies; new_id uuid;
begin
  if jsonb_typeof(company_data) <> 'object' then raise exception 'Dados da empresa invalidos' using errcode='22023'; end if;
  if target_company is null then
    if length(trim(coalesce(company_data->>'legal_name',''))) < 2 or length(trim(coalesce(company_data->>'trade_name',''))) < 2 then
      raise exception 'Razao social e nome fantasia sao obrigatorios' using errcode='22023';
    end if;
    insert into public.companies(legal_name,trade_name,cnpj,phone,cep,city,state,service_radius_km,status)
    values(trim(company_data->>'legal_name'),trim(company_data->>'trade_name'),nullif(trim(company_data->>'cnpj'),''),
      nullif(trim(company_data->>'phone'),''),nullif(trim(company_data->>'cep'),''),nullif(trim(company_data->>'city'),''),
      nullif(upper(trim(company_data->>'state')),'')::char(2),
      nullif(company_data->>'service_radius_km','')::integer,
      coalesce((company_data->>'status')::public.company_status,'pending'))
    returning * into saved;
    new_id:=saved.id;
    perform public.write_admin_audit('company_created','company',new_id::text,null,to_jsonb(saved));
  else
    select * into old_row from public.companies where id=target_company for update;
    if old_row.id is null then raise exception 'Empresa nao encontrada' using errcode='P0002'; end if;
    update public.companies set
      legal_name=case when company_data ? 'legal_name' then trim(company_data->>'legal_name') else legal_name end,
      trade_name=case when company_data ? 'trade_name' then trim(company_data->>'trade_name') else trade_name end,
      cnpj=case when company_data ? 'cnpj' then nullif(trim(company_data->>'cnpj'),'') else cnpj end,
      phone=case when company_data ? 'phone' then nullif(trim(company_data->>'phone'),'') else phone end,
      cep=case when company_data ? 'cep' then nullif(trim(company_data->>'cep'),'') else cep end,
      city=case when company_data ? 'city' then nullif(trim(company_data->>'city'),'') else city end,
      state=case when company_data ? 'state' then nullif(upper(trim(company_data->>'state')),'')::char(2) else state end,
      service_radius_km=case when company_data ? 'service_radius_km' then nullif(company_data->>'service_radius_km','')::integer else service_radius_km end,
      status=case when company_data ? 'status' then (company_data->>'status')::public.company_status else status end
    where id=target_company returning * into saved;
    if length(trim(saved.legal_name))<2 or length(trim(saved.trade_name))<2 then raise exception 'Nome de empresa invalido' using errcode='22023'; end if;
    new_id:=saved.id;
    perform public.write_admin_audit('company_updated','company',new_id::text,to_jsonb(old_row),to_jsonb(saved));
  end if;
  return new_id;
end $$;

-- Usuarios/perfis ------------------------------------------------------------
create or replace function public.admin_list_users(
  search_term text default null,
  status_filter text default null,
  page_limit integer default 50,
  page_offset integer default 0
) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
  perform public.require_super_admin();
  if page_limit not between 1 and 200 or page_offset<0 then raise exception 'Paginacao invalida' using errcode='22023'; end if;
  if status_filter is not null and status_filter not in ('pending_password','active','suspended') then raise exception 'Status invalido' using errcode='22023'; end if;
  with filtered as (
    select u.id,lower(u.email) email,u.email_confirmed_at,u.last_sign_in_at,u.created_at,
      p.first_name,p.last_name,p.full_name,p.phone,p.profile_type,p.role,p.status,p.onboarding_completed,
      am.role admin_role,am.status admin_status
    from auth.users u
    left join public.profiles p on p.id=u.id
    left join public.admin_members am on am.user_id=u.id
    where (status_filter is null or p.status=status_filter)
      and (nullif(trim(search_term),'') is null or u.email ilike '%'||trim(search_term)||'%'
        or coalesce(p.full_name,'') ilike '%'||trim(search_term)||'%')
  ), rows_data as (
    select f.*,
      coalesce((select jsonb_agg(jsonb_build_object('company_id',cm.company_id,'company_name',c.trade_name,'role',cm.role,'status',cm.status)
        order by c.trade_name) from public.company_members cm join public.companies c on c.id=cm.company_id where cm.user_id=f.id),'[]'::jsonb) memberships
    from filtered f order by f.created_at desc,f.id limit page_limit offset page_offset
  )
  select jsonb_build_object('items',coalesce((select jsonb_agg(to_jsonb(r) order by r.created_at desc,r.id) from rows_data r),'[]'::jsonb),
    'total',(select count(*) from filtered),'limit',page_limit,'offset',page_offset) into result;
  return result;
end $$;

create or replace function public.admin_update_user(target_user uuid, profile_data jsonb) returns void
language plpgsql volatile security definer set search_path='' as $$
declare uid uuid := public.require_super_admin(); old_row public.profiles; saved public.profiles;
begin
  if target_user is null or jsonb_typeof(profile_data)<>'object' then raise exception 'Dados de usuario invalidos' using errcode='22023'; end if;
  select * into old_row from public.profiles where id=target_user for update;
  if old_row.id is null then raise exception 'Perfil nao encontrado' using errcode='P0002'; end if;
  if profile_data ? 'status' and profile_data->>'status' not in ('pending_password','active','suspended') then raise exception 'Status invalido' using errcode='22023'; end if;
  if profile_data ? 'profile_type' and profile_data->>'profile_type' not in ('buyer','supplier','both') then raise exception 'Perfil comercial invalido' using errcode='22023'; end if;
  -- O proprio super admin nao pode suspender ou rebaixar a si mesmo por esta RPC.
  if target_user=uid and ((profile_data ? 'status' and profile_data->>'status'<>'active') or (profile_data ? 'role' and profile_data->>'role'<>'super_admin')) then
    raise exception 'Nao e permitido remover o proprio acesso administrativo' using errcode='42501';
  end if;
  -- Papeis administrativos sao geridos exclusivamente em admin_members, nunca por JSON arbitrario.
  update public.profiles set
    first_name=case when profile_data ? 'first_name' then nullif(trim(profile_data->>'first_name'),'') else first_name end,
    last_name=case when profile_data ? 'last_name' then nullif(trim(profile_data->>'last_name'),'') else last_name end,
    full_name=case when profile_data ? 'full_name' then nullif(trim(profile_data->>'full_name'),'') else full_name end,
    phone=case when profile_data ? 'phone' then nullif(trim(profile_data->>'phone'),'') else phone end,
    profile_type=case when profile_data ? 'profile_type' then (profile_data->>'profile_type')::public.profile_type else profile_type end,
    status=case when profile_data ? 'status' then profile_data->>'status' else status end
  where id=target_user returning * into saved;
  perform public.write_admin_audit('user_profile_updated','profile',target_user::text,to_jsonb(old_row),to_jsonb(saved));
end $$;

create or replace function public.admin_save_company_member(
  target_company uuid,
  target_user uuid,
  member_role_value public.member_role,
  member_status_value public.member_status default 'active'
) returns void
language plpgsql volatile security definer set search_path='' as $$
declare old_row public.company_members; saved public.company_members;
begin
  perform public.require_super_admin();
  if target_company is null or target_user is null or member_role_value is null or member_status_value is null then
    raise exception 'Vinculo invalido' using errcode='22023';
  end if;
  if not exists(select 1 from public.companies where id=target_company) then raise exception 'Empresa nao encontrada' using errcode='P0002'; end if;
  if not exists(select 1 from auth.users where id=target_user) then raise exception 'Usuario nao encontrado' using errcode='P0002'; end if;
  select * into old_row from public.company_members where company_id=target_company and user_id=target_user for update;
  if old_row.role='owner' and old_row.status='active' and (member_role_value<>'owner' or member_status_value<>'active')
    and not exists(select 1 from public.company_members cm where cm.company_id=target_company and cm.user_id<>target_user and cm.role='owner' and cm.status='active') then
    raise exception 'A empresa deve manter ao menos um proprietario ativo' using errcode='23514';
  end if;
  insert into public.company_members(company_id,user_id,role,status)
  values(target_company,target_user,member_role_value,member_status_value)
  on conflict(company_id,user_id) do update set role=excluded.role,status=excluded.status
  returning * into saved;
  perform public.write_admin_audit(case when old_row.user_id is null then 'company_member_created' else 'company_member_updated' end,
    'company_member',target_company::text||':'||target_user::text,
    case when old_row.user_id is null then null else to_jsonb(old_row) end,to_jsonb(saved));
end $$;

-- Produtos -------------------------------------------------------------------
create or replace function public.admin_list_products(
  search_term text default null,
  company_filter uuid default null,
  status_filter public.catalog_item_status default null,
  page_limit integer default 50,
  page_offset integer default 0
) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
  perform public.require_super_admin();
  if page_limit not between 1 and 200 or page_offset<0 then raise exception 'Paginacao invalida' using errcode='22023'; end if;
  with filtered as (
    select p.*,c.trade_name company_name,cat.name category_name
    from public.products p join public.companies c on c.id=p.company_id left join public.categories cat on cat.id=p.category_id
    where (company_filter is null or p.company_id=company_filter) and (status_filter is null or p.status=status_filter)
      and (nullif(trim(search_term),'') is null or p.name ilike '%'||trim(search_term)||'%'
        or coalesce(p.sku,'') ilike '%'||trim(search_term)||'%')
  ), rows_data as (select * from filtered order by updated_at desc,id limit page_limit offset page_offset)
  select jsonb_build_object('items',coalesce((select jsonb_agg(to_jsonb(r) order by r.updated_at desc,r.id) from rows_data r),'[]'::jsonb),
    'total',(select count(*) from filtered),'limit',page_limit,'offset',page_offset) into result;
  return result;
end $$;

create or replace function public.admin_save_product(target_product uuid, product_data jsonb) returns uuid
language plpgsql volatile security definer set search_path='' as $$
declare uid uuid:=public.require_super_admin(); old_row public.products; saved public.products; new_id uuid; product_slug text;
begin
  if jsonb_typeof(product_data)<>'object' then raise exception 'Dados do produto invalidos' using errcode='22023'; end if;
  if target_product is null then
    if nullif(product_data->>'company_id','') is null or length(trim(coalesce(product_data->>'name','')))<2 then raise exception 'Empresa e nome sao obrigatorios' using errcode='22023'; end if;
    product_slug:=lower(regexp_replace(translate(trim(coalesce(nullif(product_data->>'slug',''),product_data->>'name')),
      'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ',
      'aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC'),'[^a-zA-Z0-9]+','-','g'));
    product_slug:=trim(both '-' from product_slug);
    insert into public.products(company_id,category_id,name,slug,description,sku,unit,price,min_order_quantity,status,image_url,metadata,created_by)
    values((product_data->>'company_id')::uuid,nullif(product_data->>'category_id','')::uuid,trim(product_data->>'name'),product_slug,
      coalesce(product_data->>'description',''),nullif(trim(product_data->>'sku'),''),coalesce(nullif(trim(product_data->>'unit'),''),'un'),
      nullif(product_data->>'price','')::numeric,coalesce(nullif(product_data->>'min_order_quantity','')::numeric,1),
      coalesce((product_data->>'status')::public.catalog_item_status,'draft'),nullif(trim(product_data->>'image_url'),''),
      coalesce(product_data->'metadata','{}'::jsonb),uid) returning * into saved;
    new_id:=saved.id;
    perform public.write_admin_audit('product_created','product',new_id::text,null,to_jsonb(saved));
  else
    select * into old_row from public.products where id=target_product for update;
    if old_row.id is null then raise exception 'Produto nao encontrado' using errcode='P0002'; end if;
    update public.products set
      company_id=case when product_data ? 'company_id' then (product_data->>'company_id')::uuid else company_id end,
      category_id=case when product_data ? 'category_id' then nullif(product_data->>'category_id','')::uuid else category_id end,
      name=case when product_data ? 'name' then trim(product_data->>'name') else name end,
      slug=case when product_data ? 'slug' then trim(product_data->>'slug') else slug end,
      description=case when product_data ? 'description' then coalesce(product_data->>'description','') else description end,
      sku=case when product_data ? 'sku' then nullif(trim(product_data->>'sku'),'') else sku end,
      unit=case when product_data ? 'unit' then trim(product_data->>'unit') else unit end,
      price=case when product_data ? 'price' then nullif(product_data->>'price','')::numeric else price end,
      min_order_quantity=case when product_data ? 'min_order_quantity' then (product_data->>'min_order_quantity')::numeric else min_order_quantity end,
      status=case when product_data ? 'status' then (product_data->>'status')::public.catalog_item_status else status end,
      image_url=case when product_data ? 'image_url' then nullif(trim(product_data->>'image_url'),'') else image_url end,
      metadata=case when product_data ? 'metadata' then product_data->'metadata' else metadata end
    where id=target_product returning * into saved;
    new_id:=saved.id;
    perform public.write_admin_audit('product_updated','product',new_id::text,to_jsonb(old_row),to_jsonb(saved));
  end if;
  return new_id;
end $$;

create or replace function public.admin_archive_product(target_product uuid) returns void
language plpgsql volatile security definer set search_path='' as $$
declare old_row public.products; saved public.products;
begin
  perform public.require_super_admin();
  select * into old_row from public.products where id=target_product for update;
  if old_row.id is null then raise exception 'Produto nao encontrado' using errcode='P0002'; end if;
  update public.products set status='archived' where id=target_product returning * into saved;
  perform public.write_admin_audit('product_archived','product',target_product::text,to_jsonb(old_row),to_jsonb(saved));
end $$;

-- Planos e relatorios --------------------------------------------------------
create or replace function public.admin_list_plans() returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
  perform public.require_super_admin();
  select coalesce(jsonb_agg(jsonb_build_object(
    'id',p.id,'name',p.name,'slug',p.slug,'description',p.description,'price_monthly',p.price_monthly,
    'currency',p.currency,'product_limit',p.product_limit,'included_users',p.included_users,'is_free',p.is_free,
    'is_enterprise',p.is_enterprise,'is_active',p.is_active,'is_featured',p.is_featured,'trial_available',p.trial_available,
    'sort_order',p.sort_order,'active_subscriptions',(select count(*) from public.subscriptions s where s.plan_id=p.id and s.status in ('active','trialing','free')),
    'features',coalesce((select jsonb_agg(to_jsonb(pf) order by pf.feature_key) from public.plan_features pf where pf.plan_id=p.id),'[]'::jsonb)
  ) order by p.sort_order,p.name),'[]'::jsonb) into result from public.plans p;
  return result;
end $$;

create or replace function public.admin_create_plan(plan_data jsonb, features_data jsonb) returns uuid
language plpgsql volatile security definer set search_path='' as $$
declare uid uuid:=public.require_super_admin(); new_plan public.plans; f jsonb; products_limit integer; users_limit integer;
  plan_slug text; plan_is_free boolean; plan_is_enterprise boolean; plan_trial boolean; plan_price numeric;
begin
  if jsonb_typeof(plan_data) is distinct from 'object' or jsonb_typeof(features_data) is distinct from 'array' then
    raise exception 'Formato de plano invalido' using errcode='22023';
  end if;
  if length(trim(coalesce(plan_data->>'name',''))) not between 2 and 80
    or length(coalesce(plan_data->>'description',''))>2000 then
    raise exception 'Nome ou descricao invalidos' using errcode='22023';
  end if;
  plan_slug:=lower(trim(coalesce(plan_data->>'slug','')));
  if plan_slug !~ '^[a-z0-9]+(?:-[a-z0-9]+)*$' then raise exception 'Slug invalido' using errcode='22023'; end if;
  if jsonb_array_length(features_data)<>17
    or (select count(distinct value->>'feature_key') from jsonb_array_elements(features_data))<>17 then
    raise exception 'Envie as 17 features, sem duplicacao' using errcode='22023';
  end if;
  for f in select value from jsonb_array_elements(features_data) loop
    if jsonb_typeof(f->'enabled') is distinct from 'boolean'
      or jsonb_typeof(f->'config_json') is distinct from 'object'
      or length(coalesce(f->'config_json'->>'label',''))>180 then
      raise exception 'Feature invalida' using errcode='22023';
    end if;
  end loop;
  select (value->>'limit_value')::integer into products_limit from jsonb_array_elements(features_data) where value->>'feature_key'='products_limit';
  select (value->>'limit_value')::integer into users_limit from jsonb_array_elements(features_data) where value->>'feature_key'='users_limit';
  if products_limit<0 or users_limit<1 then raise exception 'Limites invalidos' using errcode='22023'; end if;
  plan_is_free:=coalesce((plan_data->>'is_free')::boolean,false);
  plan_is_enterprise:=coalesce((plan_data->>'is_enterprise')::boolean,false);
  if plan_is_free and plan_is_enterprise then raise exception 'Plano nao pode ser gratis e enterprise' using errcode='22023'; end if;
  plan_price:=case when plan_is_enterprise then null else (plan_data->>'price_monthly')::numeric end;
  if plan_is_free and plan_price is distinct from 0 then raise exception 'Plano gratis deve ter preco zero' using errcode='22023'; end if;
  if not plan_is_enterprise and (plan_price is null or plan_price<0) then raise exception 'Preco mensal invalido' using errcode='22023'; end if;
  plan_trial:=case when plan_is_free or plan_is_enterprise then false else coalesce((plan_data->>'trial_available')::boolean,true) end;
  insert into public.plans(name,slug,description,price_monthly,product_limit,included_users,is_free,is_enterprise,is_active,is_featured,trial_available,sort_order)
  values(trim(plan_data->>'name'),plan_slug,coalesce(plan_data->>'description',''),plan_price,products_limit,users_limit,
    plan_is_free,plan_is_enterprise,coalesce((plan_data->>'is_active')::boolean,true),coalesce((plan_data->>'is_featured')::boolean,false),
    plan_trial,coalesce((plan_data->>'sort_order')::integer,0)) returning * into new_plan;
  insert into public.plan_features(plan_id,feature_key,enabled,limit_value,config_json)
  select new_plan.id,value->>'feature_key',(value->>'enabled')::boolean,(value->>'limit_value')::integer,value->'config_json'
  from jsonb_array_elements(features_data);
  perform public.write_admin_audit('plan_created','plan',new_plan.id::text,null,
    jsonb_build_object('plan',to_jsonb(new_plan),'features',features_data));
  return new_plan.id;
end $$;

create or replace function public.admin_deactivate_plan(target_plan uuid) returns void
language plpgsql volatile security definer set search_path='' as $$
declare old_row public.plans; saved public.plans;
begin
  perform public.require_super_admin();
  select * into old_row from public.plans where id=target_plan for update;
  if old_row.id is null then raise exception 'Plano nao encontrado' using errcode='P0002'; end if;
  if old_row.is_free then raise exception 'O plano gratuito base nao pode ser desativado' using errcode='22023'; end if;
  update public.plans set is_active=false,is_featured=false where id=target_plan returning * into saved;
  perform public.write_admin_audit('plan_deactivated','plan',target_plan::text,to_jsonb(old_row),to_jsonb(saved));
end $$;

create or replace function public.admin_get_reports(
  period_start timestamptz default (now()-interval '30 days'),
  period_end timestamptz default now()
) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
  perform public.require_super_admin();
  if period_start is null or period_end is null or period_start>=period_end or period_end-period_start>interval '366 days' then
    raise exception 'Periodo invalido' using errcode='22023';
  end if;
  select jsonb_build_object(
    'period',jsonb_build_object('start',period_start,'end',period_end),
    'totals',jsonb_build_object(
      'companies',(select count(*) from public.companies),
      'active_companies',(select count(*) from public.companies where status='active'),
      'users',(select count(*) from auth.users),
      'active_profiles',(select count(*) from public.profiles where status='active'),
      'products',(select count(*) from public.products where status<>'archived'),
      'active_products',(select count(*) from public.products where status='active'),
      'opportunities',(select count(*) from public.opportunities),
      'quotes',(select count(*) from public.quotes),
      'connections',(select count(*) from public.connections where status='accepted')
    ),
    'new_in_period',jsonb_build_object(
      'companies',(select count(*) from public.companies where created_at>=period_start and created_at<period_end),
      'users',(select count(*) from auth.users where created_at>=period_start and created_at<period_end),
      'products',(select count(*) from public.products where created_at>=period_start and created_at<period_end),
      'opportunities',(select count(*) from public.opportunities where created_at>=period_start and created_at<period_end)
    ),
    'subscriptions_by_plan',coalesce((select jsonb_agg(to_jsonb(x) order by x.subscriptions desc,x.plan_name) from (
      select p.name plan_name,p.slug plan_slug,count(s.id) subscriptions
      from public.plans p left join public.subscriptions s on s.plan_id=p.id and s.status in ('active','trialing','free')
      group by p.id,p.name,p.slug
    ) x),'[]'::jsonb),
    'companies_by_status',coalesce((select jsonb_agg(to_jsonb(x) order by x.status) from (
      select status::text status,count(*) total from public.companies group by status
    ) x),'[]'::jsonb)
  ) into result;
  return result;
end $$;

-- Fail closed: nenhum helper interno fica executavel pelos papeis da API.
revoke all on function public.require_super_admin(),
  public.write_admin_audit(text,text,text,jsonb,jsonb) from public,anon,authenticated;

-- Apenas as RPCs de interface sao expostas a usuarios autenticados; cada uma
-- revalida admin_members em tempo de execucao.
revoke all on function public.admin_list_companies(text,public.company_status,integer,integer),
  public.admin_save_company(uuid,jsonb),public.admin_list_users(text,text,integer,integer),
  public.admin_update_user(uuid,jsonb),public.admin_save_company_member(uuid,uuid,public.member_role,public.member_status),
  public.admin_list_products(text,uuid,public.catalog_item_status,integer,integer),
  public.admin_save_product(uuid,jsonb),public.admin_archive_product(uuid),
  public.admin_list_plans(),public.admin_create_plan(jsonb,jsonb),public.admin_deactivate_plan(uuid),
  public.admin_get_reports(timestamptz,timestamptz) from public,anon,authenticated;

grant execute on function public.admin_list_companies(text,public.company_status,integer,integer),
  public.admin_save_company(uuid,jsonb),public.admin_list_users(text,text,integer,integer),
  public.admin_update_user(uuid,jsonb),public.admin_save_company_member(uuid,uuid,public.member_role,public.member_status),
  public.admin_list_products(text,uuid,public.catalog_item_status,integer,integer),
  public.admin_save_product(uuid,jsonb),public.admin_archive_product(uuid),
  public.admin_list_plans(),public.admin_create_plan(jsonb,jsonb),public.admin_deactivate_plan(uuid),
  public.admin_get_reports(timestamptz,timestamptz) to authenticated;

commit;
