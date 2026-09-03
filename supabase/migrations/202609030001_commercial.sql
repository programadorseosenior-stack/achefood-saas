-- AcheFood commercial foundation. Requires 202609020001_foundation.sql.
-- No gateway/automatic charging. No remote database has been modified.
begin;
create table public.plans (
 id uuid primary key default gen_random_uuid(), name text not null, slug text not null unique,
 description text not null default '', price_monthly numeric(12,2), currency text not null default 'BRL' check(currency='BRL'),
 product_limit integer check(product_limit>=0), included_users integer check(included_users>=1),
 is_free boolean not null default false, is_enterprise boolean not null default false,
 is_active boolean not null default true, is_featured boolean not null default false,
 trial_available boolean not null default true, sort_order integer not null default 0,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 check ((is_enterprise and price_monthly is null) or (not is_enterprise and price_monthly is not null and price_monthly>=0)),
 check(not is_free or (price_monthly=0 and not is_enterprise)),
 check(not ((is_free or is_enterprise) and trial_available))
);
create table public.plan_features (
 plan_id uuid not null references public.plans(id) on delete cascade,
 feature_key text not null check(feature_key in ('company_profile','catalog','products_limit','users_limit','csv_import','search_visibility','radius_search','buyer_contacts','opportunities','eu_tenho','analytics','commercial_page','search_highlight','support_level','basic_search','categories','supplier_view')),
 enabled boolean not null default false, limit_value integer check(limit_value>=0),
 config_json jsonb not null default '{}' check(jsonb_typeof(config_json)='object'), primary key(plan_id,feature_key)
);
create table public.subscriptions (
 id uuid primary key default gen_random_uuid(), company_id uuid not null unique references public.companies(id) on delete cascade,
 plan_id uuid not null references public.plans(id), status text not null check(status in ('trialing','active','past_due','cancelled','expired','free')),
 trial_started_at timestamptz, trial_ends_at timestamptz, trial_plan_id uuid references public.plans(id),
 trial_status text check(trial_status in ('active','expired','converted','cancelled')),
 current_period_start timestamptz, current_period_end timestamptz, cancel_at_period_end boolean not null default false,
 provider text, provider_subscription_id text unique,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 check(status<>'trialing' or (trial_started_at is not null and trial_ends_at>trial_started_at and trial_plan_id is not null and trial_status='active')),
 check(status<>'active' or (provider is not null and provider_subscription_id is not null and current_period_end is not null))
);
create table public.trial_claims (
 user_id uuid primary key references auth.users(id) on delete restrict,
 company_id uuid not null references public.companies(id) on delete restrict, claimed_at timestamptz not null default now()
);
create table public.billing_addons (
 id uuid primary key default gen_random_uuid(), feature_key text not null unique check(feature_key='additional_user'),
 name text not null, price_monthly numeric(12,2) not null check(price_monthly>=0), currency text not null default 'BRL' check(currency='BRL'),
 is_active boolean not null default true, created_at timestamptz not null default now()
);
create table public.subscription_addons (
 id uuid primary key default gen_random_uuid(), subscription_id uuid not null references public.subscriptions(id) on delete cascade,
 addon_id uuid not null references public.billing_addons(id), quantity integer not null check(quantity>0),
 status text not null check(status in ('active','cancelled','pending')), provider_item_id text,
 current_period_end timestamptz not null, created_at timestamptz not null default now(), unique(subscription_id,addon_id)
);
create table public.commercial_events (
 id bigint generated always as identity primary key, company_id uuid references public.companies(id) on delete set null,
 actor_id uuid references auth.users(id) on delete set null,
 event_type text not null check(event_type in ('trial_started','plan_viewed','plan_selected','trial_expired','free_selected','checkout_started','subscription_created','subscription_upgraded','subscription_downgraded','subscription_cancelled','additional_user_purchased')),
 metadata jsonb not null default '{}', created_at timestamptz not null default now()
);
create table public.enterprise_leads (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id),
 company_name text not null check(length(company_name) between 2 and 180),
 contact_name text not null check(length(contact_name) between 2 and 180),
 email text not null check(length(email) between 5 and 254),
 message text not null check(length(message) between 10 and 4000),
 status text not null default 'new' check(status in ('new','contacted','qualified','closed')),
 created_at timestamptz not null default now()
);
create index enterprise_leads_user_created on public.enterprise_leads(user_id,created_at);
create or replace function public.is_super_admin() returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.admin_members where user_id=auth.uid() and role='super_admin' and status='active')
$$;
revoke all on function public.is_super_admin() from public;
grant execute on function public.is_super_admin() to authenticated,anon;
alter table public.plans enable row level security;
alter table public.plan_features enable row level security;
alter table public.subscriptions enable row level security;
alter table public.trial_claims enable row level security;
alter table public.billing_addons enable row level security;
alter table public.subscription_addons enable row level security;
alter table public.commercial_events enable row level security;
alter table public.enterprise_leads enable row level security;
create policy plans_read on public.plans for select to anon,authenticated using(is_active or public.is_super_admin());
create policy features_read on public.plan_features for select to anon,authenticated using(exists(select 1 from public.plans p where p.id=plan_id));
create policy subscriptions_read on public.subscriptions for select to authenticated using(public.is_company_member(company_id) or public.is_super_admin());
create policy addons_read on public.billing_addons for select to anon,authenticated using(is_active or public.is_super_admin());
create policy subscription_addons_read on public.subscription_addons for select to authenticated using(exists(select 1 from public.subscriptions s where s.id=subscription_id and (public.is_company_member(s.company_id) or public.is_super_admin())));
create policy events_admin_read on public.commercial_events for select to authenticated using(public.is_super_admin());
create policy leads_read on public.enterprise_leads for select to authenticated using(user_id=auth.uid() or public.is_super_admin());
revoke all on public.plans,public.plan_features,public.subscriptions,public.trial_claims,public.billing_addons,public.subscription_addons,public.commercial_events,public.enterprise_leads from anon,authenticated;
grant select on public.plans,public.plan_features,public.billing_addons to anon,authenticated;
grant select on public.subscriptions,public.subscription_addons,public.commercial_events,public.enterprise_leads to authenticated;
-- No client can grant a paid plan/trial/team seat. A future invitation RPC must enforce limits.
drop policy memberships_owner_manage on public.company_members;
revoke insert,update,delete on public.company_members from anon,authenticated;
create trigger plans_updated before update on public.plans for each row execute function public.set_updated_at();
create trigger subscriptions_updated before update on public.subscriptions for each row execute function public.set_updated_at();
insert into public.plans(name,slug,description,price_monthly,product_limit,included_users,is_free,is_enterprise,trial_available,is_featured,sort_order) values
 ('Grátis','free','Continue no AcheFood com recursos limitados.',0,0,1,true,false,false,false,0),
 ('Basic','basic','Ideal para pequenas empresas que estão começando e querem ter presença no AcheFood.',29.90,20,1,false,false,true,false,1),
 ('Essential','essential','Para empresas que querem mais visibilidade, mais produtos e mais oportunidades de negócio.',49.90,100,5,false,false,true,false,2),
 ('Professional','professional','Para empresas que possuem equipes de vendas e operação comercial ativa.',99.90,500,10,false,false,true,true,3),
 ('Premium','premium','Para empresas que querem o máximo de recursos, exposição e oportunidades.',199.90,null,20,false,false,true,false,4),
 ('Enterprise','enterprise','Soluções personalizadas para indústrias e grandes operações.',null,null,null,false,true,false,false,5)
 on conflict(slug) do nothing;
-- Qualitative labels do not invent numeric quotas. All Free capabilities remain editable.
insert into public.plan_features(plan_id,feature_key,enabled,limit_value,config_json)
select p.id, f.key,
 case when f.key in ('csv_import','analytics','search_highlight') then
   case when f.key='search_highlight' then p.slug in ('professional','premium','enterprise') else p.slug in ('essential','professional','premium','enterprise') end
 when f.key in ('catalog','buyer_contacts','opportunities','eu_tenho','radius_search','commercial_page') then p.slug<>'free' else true end,
 case f.key when 'products_limit' then p.product_limit when 'users_limit' then p.included_users else null end,
 jsonb_build_object('label',case
 when f.key='products_limit' then coalesce(p.product_limit::text,'Ilimitados')
 when f.key='users_limit' then coalesce(p.included_users::text,'Personalizados')
 when f.key='search_visibility' then case p.slug when 'free' then 'Básico' when 'basic' then 'Básico' when 'essential' then 'Melhor exposição' when 'professional' then 'Alta exposição' when 'premium' then 'Destaque máximo' else 'Sob medida' end
 when f.key='analytics' then case p.slug when 'essential' then 'Básicas' when 'professional' then 'Completas' when 'premium' then 'Avançadas' when 'enterprise' then 'Sob medida' else 'Não' end
 when f.key='support_level' then case p.slug when 'free' then 'Básico' when 'basic' then 'E-mail' when 'essential' then 'E-mail + chat' when 'professional' then 'Prioritário' when 'premium' then 'Prioritário + gerente' else 'Especializado + SLA' end
 when f.key='commercial_page' then case p.slug when 'free' then 'Não' when 'basic' then 'Básica' when 'essential' then 'Completa standard' when 'professional' then 'Completa' when 'premium' then 'Premium' else 'Sob medida' end
 when f.key in ('opportunities','eu_tenho') then case p.slug when 'free' then 'Não' when 'basic' then 'Limitado' else 'Sim' end
 when f.key='search_highlight' then case p.slug when 'professional' then 'Sim' when 'premium' then 'Prioritário / máximo' when 'enterprise' then 'Sob medida' else 'Não' end
 when f.key='csv_import' then case when p.slug in ('free','basic') then 'Não' else 'Sim' end
 when f.key in ('catalog','buyer_contacts','radius_search') and p.slug='free' then 'Não' else 'Sim' end)
from public.plans p cross join (values ('company_profile'),('catalog'),('products_limit'),('users_limit'),('csv_import'),('search_visibility'),('radius_search'),('buyer_contacts'),('opportunities'),('eu_tenho'),('analytics'),('commercial_page'),('search_highlight'),('support_level'),('basic_search'),('categories'),('supplier_view')) f(key)
on conflict(plan_id,feature_key) do nothing;
insert into public.billing_addons(feature_key,name,price_monthly) values('additional_user','Usuário adicional',10.00) on conflict(feature_key) do nothing;
create or replace function public.get_company_entitlements(target_company uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare s public.subscriptions; p public.plans; effective_status text; extra integer:=0; feature_data jsonb;
begin
 if not (public.is_company_member(target_company) or public.is_super_admin()) then raise exception 'Acesso negado' using errcode='42501'; end if;
 select * into s from public.subscriptions where company_id=target_company;
 effective_status:=coalesce(s.status,'free');
 if s.status='trialing' and s.trial_ends_at>now() then
   select * into p from public.plans where id=s.trial_plan_id;
 elsif s.status='active' and s.current_period_end>now() then
   select * into p from public.plans where id=s.plan_id;
   select coalesce(sum(sa.quantity),0)::integer into extra from public.subscription_addons sa join public.billing_addons a on a.id=sa.addon_id where sa.subscription_id=s.id and sa.status='active' and sa.current_period_end>now() and a.feature_key='additional_user';
 else
   if s.status in ('trialing','active') then effective_status:='expired'; end if;
   select * into p from public.plans where slug='free';
 end if;
 if p.id is null then raise exception 'Plano efetivo indisponível'; end if;
 select coalesce(jsonb_agg(to_jsonb(f) order by f.feature_key),'[]'::jsonb) into feature_data from public.plan_features f where f.plan_id=p.id;
 return jsonb_build_object('company_id',target_company,'plan_id',p.id,'plan_name',p.name,'plan_slug',p.slug,'features',feature_data,'included_users',p.included_users,'additional_users',extra,'total_users',case when p.included_users is null then null else p.included_users+extra end,'product_limit',p.product_limit,'status',effective_status,'trial_ends_at',s.trial_ends_at,'trial_status',case when s.status='trialing' and s.trial_ends_at<=now() then 'expired' else s.trial_status end);
end $$;
create or replace function public.complete_onboarding(company_name text,selected_plan text) returns uuid
language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); cid uuid; p public.plans; confirmed timestamptz; has_claim boolean;
begin
 if uid is null then raise exception 'Autenticação necessária' using errcode='42501'; end if;
 -- Serializes concurrent requests for this user, including Enterprise submissions.
 select email_confirmed_at into confirmed from auth.users where id=uid for update;
 if confirmed is null then raise exception 'Confirme seu e-mail antes de continuar' using errcode='42501'; end if;
 if company_name is null or length(trim(company_name)) not between 2 and 180 then raise exception 'Nome da empresa inválido'; end if;
 select cm.company_id into cid from public.company_members cm where cm.user_id=uid and cm.role='owner' and cm.status='active' order by cm.created_at limit 1;
 if cid is not null then return cid; end if;
 select * into p from public.plans where slug=selected_plan and is_active and not is_enterprise;
 if p.id is null then raise exception 'Plano indisponível'; end if;
 select exists(select 1 from public.trial_claims where user_id=uid) into has_claim;
 if not p.is_free and (not p.trial_available or has_claim) then raise exception 'Trial indisponível; selecione o plano grátis'; end if;
 insert into public.companies(legal_name,trade_name) values(trim(company_name),trim(company_name)) returning id into cid;
 insert into public.company_members(company_id,user_id,role,status) values(cid,uid,'owner','active');
 insert into public.profiles(id,onboarding_completed) values(uid,true) on conflict(id) do update set onboarding_completed=true;
 insert into public.subscriptions(company_id,plan_id,status,trial_started_at,trial_ends_at,trial_plan_id,trial_status)
 values(cid,p.id,case when p.is_free then 'free' else 'trialing' end,case when not p.is_free then now() end,case when not p.is_free then now()+interval '30 days' end,case when not p.is_free then p.id end,case when not p.is_free then 'active' end);
 if not p.is_free then insert into public.trial_claims(user_id,company_id) values(uid,cid); end if;
 insert into public.commercial_events(company_id,actor_id,event_type,metadata) values(cid,uid,case when p.is_free then 'free_selected' else 'trial_started' end,jsonb_build_object('plan_id',p.id));
 return cid;
end $$;
create or replace function public.select_free_plan(target_company uuid) returns void
language plpgsql security definer set search_path='' as $$
declare fid uuid; prior public.subscriptions;
begin
 if not exists(select 1 from public.company_members where company_id=target_company and user_id=auth.uid() and role='owner' and status='active') then raise exception 'Apenas o proprietário pode alterar o plano' using errcode='42501'; end if;
 select * into prior from public.subscriptions where company_id=target_company for update;
 if prior.provider_subscription_id is not null and prior.status in ('active','past_due') then raise exception 'Cancele a assinatura pelo provedor antes de mudar para grátis'; end if;
 select id into fid from public.plans where slug='free';
 if prior.status='trialing' and prior.trial_ends_at<=now() then insert into public.commercial_events(company_id,actor_id,event_type) values(target_company,auth.uid(),'trial_expired'); end if;
 update public.subscriptions set plan_id=fid,status='free',trial_status=case when trial_status='active' then case when trial_ends_at<=now() then 'expired' else 'cancelled' end else trial_status end where company_id=target_company;
 if not found then raise exception 'Assinatura não encontrada'; end if;
 insert into public.commercial_events(company_id,actor_id,event_type) values(target_company,auth.uid(),'free_selected');
end $$;
create or replace function public.admin_save_plan(target_plan uuid,plan_data jsonb,features_data jsonb) returns void
language plpgsql security definer set search_path='' as $$
declare old_plan jsonb; old_features jsonb; products integer; users_count integer; f jsonb;
begin
 if not public.is_super_admin() then raise exception 'Acesso restrito ao Super Admin' using errcode='42501'; end if;
 if jsonb_typeof(plan_data) is distinct from 'object' or jsonb_typeof(features_data) is distinct from 'array' then raise exception 'Formato inválido'; end if;
 if length(trim(coalesce(plan_data->>'name',''))) not between 2 and 80 or length(coalesce(plan_data->>'description',''))>2000 then raise exception 'Nome ou descrição inválidos'; end if;
 if (select count(*) from jsonb_array_elements(features_data))<>17 or (select count(distinct value->>'feature_key') from jsonb_array_elements(features_data))<>17 then raise exception 'Envie as 17 features, sem duplicação'; end if;
 for f in select value from jsonb_array_elements(features_data) loop
   if jsonb_typeof(f->'enabled') is distinct from 'boolean' or jsonb_typeof(f->'config_json') is distinct from 'object' or length(coalesce(f->'config_json'->>'label',''))>180 then raise exception 'Feature inválida'; end if;
 end loop;
 select (value->>'limit_value')::integer into products from jsonb_array_elements(features_data) where value->>'feature_key'='products_limit';
 select (value->>'limit_value')::integer into users_count from jsonb_array_elements(features_data) where value->>'feature_key'='users_limit';
 if products<0 or users_count<1 then raise exception 'Limites inválidos'; end if;
 select to_jsonb(p) into old_plan from public.plans p where p.id=target_plan for update;
 if old_plan is null then raise exception 'Plano não encontrado'; end if;
 select jsonb_agg(to_jsonb(pf)) into old_features from public.plan_features pf where plan_id=target_plan;
 update public.plans set name=trim(plan_data->>'name'),description=coalesce(plan_data->>'description',''),
 price_monthly=case when is_enterprise then null else (plan_data->>'price_monthly')::numeric end,
 product_limit=products,included_users=users_count,
 is_active=coalesce((plan_data->>'is_active')::boolean,is_active),is_featured=coalesce((plan_data->>'is_featured')::boolean,is_featured),
 trial_available=case when is_free or is_enterprise then false else coalesce((plan_data->>'trial_available')::boolean,trial_available) end,
 sort_order=coalesce((plan_data->>'sort_order')::integer,sort_order) where id=target_plan;
 delete from public.plan_features where plan_id=target_plan;
 insert into public.plan_features(plan_id,feature_key,enabled,limit_value,config_json)
 select target_plan,value->>'feature_key',(value->>'enabled')::boolean,(value->>'limit_value')::integer,value->'config_json' from jsonb_array_elements(features_data);
 insert into public.audit_logs(actor_id,action,entity_type,entity_id,old_value,new_value)
 values(auth.uid(),'plan_updated','plans',target_plan::text,jsonb_build_object('plan',old_plan,'features',old_features),jsonb_build_object('plan',plan_data,'features',features_data));
end $$;
create or replace function public.submit_enterprise_lead(company_name text,contact_name text,email text,message text) returns uuid
language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); confirmed timestamptz; lead_id uuid;
begin
 if uid is null then raise exception 'Autenticação necessária' using errcode='42501'; end if;
 select email_confirmed_at into confirmed from auth.users where id=uid for update;
 if confirmed is null then raise exception 'Confirme seu e-mail' using errcode='42501'; end if;
 if email is null or email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then raise exception 'E-mail inválido'; end if;
 if exists(select 1 from public.enterprise_leads e where e.user_id=uid and e.created_at>now()-interval '5 minutes') then raise exception 'Aguarde antes de enviar outra solicitação'; end if;
 insert into public.enterprise_leads(user_id,company_name,contact_name,email,message) values(uid,trim(company_name),trim(contact_name),lower(trim(email)),trim(message)) returning id into lead_id;
 return lead_id;
end $$;
revoke all on function public.get_company_entitlements(uuid),public.complete_onboarding(text,text),public.select_free_plan(uuid),public.admin_save_plan(uuid,jsonb,jsonb),public.submit_enterprise_lead(text,text,text,text) from public;
grant execute on function public.get_company_entitlements(uuid),public.complete_onboarding(text,text),public.select_free_plan(uuid),public.admin_save_plan(uuid,jsonb,jsonb),public.submit_enterprise_lead(text,text,text,text) to authenticated;
grant all on public.plans,public.plan_features,public.subscriptions,public.trial_claims,public.billing_addons,public.subscription_addons,public.commercial_events,public.enterprise_leads to service_role;
grant usage,select on sequence public.commercial_events_id_seq to service_role;
commit;
