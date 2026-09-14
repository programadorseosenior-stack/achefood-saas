-- Perfil operacional, busca geografica e dados demo isolados.
begin;

alter table public.profiles add column if not exists avatar_url text;
alter table public.profiles add column if not exists is_demo boolean not null default false;
alter table public.companies add column if not exists logo_url text;
alter table public.companies add column if not exists is_demo boolean not null default false;
alter table public.companies add column if not exists address_line text;
alter table public.companies add column if not exists neighborhood text;
alter table public.companies add column if not exists complement text;

create index if not exists companies_geo_active_idx on public.companies(latitude, longitude)
  where status='active' and latitude is not null and longitude is not null;
create index if not exists companies_demo_idx on public.companies(is_demo) where is_demo;
create index if not exists profiles_demo_idx on public.profiles(is_demo) where is_demo;

create or replace function public.is_demo_user() returns boolean
language sql stable security definer set search_path='' as $$
  select coalesce((select p.is_demo from public.profiles p where p.id=auth.uid()),false)
$$;
revoke all on function public.is_demo_user() from public;
grant execute on function public.is_demo_user() to authenticated;

drop policy if exists companies_marketplace_select on public.companies;

drop policy if exists products_read on public.products;
create policy products_read on public.products for select to authenticated
  using (
    public.is_company_member(company_id) or public.is_super_admin() or
    (status='active' and exists (
      select 1 from public.companies c where c.id=company_id
        and c.is_demo=public.is_demo_user()
    ))
  );

create or replace function public.search_marketplace_products(
  search_text text default '', origin_lat double precision default null,
  origin_lng double precision default null, radius_km integer default null,
  result_limit integer default 100
) returns table(
  id uuid, name text, description text, image_url text, company_id uuid,
  supplier_name text, supplier_city text, supplier_state text,
  category_name text, distance_km numeric
)
language sql stable security definer set search_path='' as $$
  with candidates as (
    select p.id,p.name,p.description,p.image_url,p.company_id,
      c.trade_name supplier_name,c.city supplier_city,c.state::text supplier_state,
      cat.name category_name,
      case when origin_lat is null or origin_lng is null or c.latitude is null or c.longitude is null then null
      else 6371 * acos(least(1,greatest(-1,
        cos(radians(origin_lat))*cos(radians(c.latitude::double precision))*
        cos(radians(c.longitude::double precision)-radians(origin_lng))+
        sin(radians(origin_lat))*sin(radians(c.latitude::double precision))
      ))) end distance
    from public.products p
    join public.companies c on c.id=p.company_id
    left join public.categories cat on cat.id=p.category_id
    where auth.uid() is not null and p.status='active' and c.status='active'
      and (public.is_super_admin() or c.is_demo=public.is_demo_user())
      and (radius_km is null or radius_km in (2,5,10,20,50,100))
      and (trim(coalesce(search_text,''))='' or
        to_tsvector('simple',coalesce(p.name,'')||' '||coalesce(p.description,'')||' '||coalesce(cat.name,'')||' '||coalesce(c.trade_name,''))
        @@ plainto_tsquery('simple',trim(search_text)))
  )
  select id,name,description,image_url,company_id,supplier_name,supplier_city,supplier_state,category_name,
    case when distance is null then null else round(distance::numeric,1) end
  from candidates
  where radius_km is null or (distance is not null and distance<=radius_km)
  order by distance nulls last,name
  limit least(greatest(result_limit,1),200)
$$;
revoke all on function public.search_marketplace_products(text,double precision,double precision,integer,integer) from public;
grant execute on function public.search_marketplace_products(text,double precision,double precision,integer,integer) to authenticated;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values ('profile-media','profile-media',true,5242880,array['image/jpeg','image/png','image/webp'])
on conflict(id) do update set public=excluded.public,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;

drop policy if exists profile_media_insert on storage.objects;
drop policy if exists profile_media_update on storage.objects;
drop policy if exists profile_media_delete on storage.objects;
create policy profile_media_insert on storage.objects for insert to authenticated
with check (bucket_id='profile-media' and (
  ((storage.foldername(name))[1]='avatars' and (storage.foldername(name))[2]=auth.uid()::text) or
  ((storage.foldername(name))[1]='companies' and exists(select 1 from public.company_members cm where cm.user_id=auth.uid() and cm.status='active' and cm.role in ('owner','manager') and cm.company_id::text=(storage.foldername(name))[2])) or public.is_super_admin()
));
create policy profile_media_update on storage.objects for update to authenticated
using (bucket_id='profile-media' and (((storage.foldername(name))[1]='avatars' and (storage.foldername(name))[2]=auth.uid()::text) or ((storage.foldername(name))[1]='companies' and exists(select 1 from public.company_members cm where cm.user_id=auth.uid() and cm.status='active' and cm.role in ('owner','manager') and cm.company_id::text=(storage.foldername(name))[2])) or public.is_super_admin()))
with check (bucket_id='profile-media' and (((storage.foldername(name))[1]='avatars' and (storage.foldername(name))[2]=auth.uid()::text) or ((storage.foldername(name))[1]='companies' and exists(select 1 from public.company_members cm where cm.user_id=auth.uid() and cm.status='active' and cm.role in ('owner','manager') and cm.company_id::text=(storage.foldername(name))[2])) or public.is_super_admin()));
create policy profile_media_delete on storage.objects for delete to authenticated
using (bucket_id='profile-media' and (((storage.foldername(name))[1]='avatars' and (storage.foldername(name))[2]=auth.uid()::text) or ((storage.foldername(name))[1]='companies' and exists(select 1 from public.company_members cm where cm.user_id=auth.uid() and cm.status='active' and cm.role in ('owner','manager') and cm.company_id::text=(storage.foldername(name))[2])) or public.is_super_admin()));

grant update(avatar_url) on public.profiles to authenticated;
grant update(logo_url,address_line,neighborhood,complement) on public.companies to authenticated;

-- Marca somente a conta de demonstracao acordada. Nenhuma conta real e convertida por padrao.
update public.profiles p set is_demo=true
from auth.users u where u.id=p.id and lower(u.email)='programador.seosenior+cliente@gmail.com';

do $$
declare demo_user uuid; demo_company uuid; supplier_id uuid; cat_id uuid;
  supplier_names text[]:=array['Laticínios Bom Sabor','Distribuidora Exemplo','Casa do Queijo','Requinte Laticínios','Empório Paulista'];
  cities text[]:=array['São Paulo','Osasco','Guarulhos','Barueri','Santo André'];
  lats numeric[]:=array[-23.550520,-23.532500,-23.454300,-23.511200,-23.663900];
  lngs numeric[]:=array[-46.633308,-46.791700,-46.533700,-46.876500,-46.538300];
  products text[]:=array['Mussarela','Bacon','Requeijão','Presunto','Queijo parmesão','Leite integral','Creme de leite','Manteiga','Iogurte natural','Queijo prato','Mortadela','Peito de peru','Provolone','Gorgonzola','Cream cheese','Ricota','Coalhada','Doce de leite','Queijo minas','Queijo coalho'];
  i integer; j integer;
begin
  select id into demo_user from auth.users where lower(email)='programador.seosenior+cliente@gmail.com' limit 1;
  if demo_user is null then return; end if;
  select cm.company_id into demo_company from public.company_members cm where cm.user_id=demo_user and cm.status='active' order by cm.created_at limit 1;
  if demo_company is not null then update public.companies set is_demo=true where id=demo_company; end if;
  select id into cat_id from public.categories where is_active order by created_at limit 1;
  for i in 1..5 loop
    supplier_id := ('9d14000'||i||'-0000-4000-8000-000000000001')::uuid;
    insert into public.companies(id,legal_name,trade_name,city,state,latitude,longitude,status,is_demo)
    values(supplier_id,supplier_names[i]||' LTDA',supplier_names[i],cities[i],'SP',lats[i],lngs[i],'active',true)
    on conflict(id) do update set trade_name=excluded.trade_name,city=excluded.city,state=excluded.state,latitude=excluded.latitude,longitude=excluded.longitude,status='active',is_demo=true;
    for j in 1..15 loop
      insert into public.products(company_id,category_id,name,slug,description,unit,status,created_by,metadata)
      values(supplier_id,cat_id,products[((j+i-2)%20)+1],
        'demo-'||i||'-'||j,'Produto demonstrativo para cotação.','un','active',demo_user,
        jsonb_build_object('is_demo',true,'seed','achefood-demo-v1'))
      on conflict(company_id,slug) do update set name=excluded.name,description=excluded.description,status='active',metadata=excluded.metadata;
    end loop;
  end loop;
end $$;

create or replace function public.get_admin_dashboard_metrics() returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
  if not public.is_super_admin() then raise exception 'Acesso administrativo negado' using errcode='42501'; end if;
  return jsonb_build_object(
    'companies',(select count(*) from public.companies where not is_demo),
    'suppliers',(select count(distinct cm.user_id) from public.company_members cm join public.profiles p on p.id=cm.user_id join public.companies c on c.id=cm.company_id where cm.status='active' and not p.is_demo and not c.is_demo and p.profile_type in ('supplier','both')),
    'buyers',(select count(distinct cm.user_id) from public.company_members cm join public.profiles p on p.id=cm.user_id join public.companies c on c.id=cm.company_id where cm.status='active' and not p.is_demo and not c.is_demo and p.profile_type in ('buyer','both')),
    'products',(select count(*) from public.products p join public.companies c on c.id=p.company_id where not c.is_demo)
  );
end $$;

create or replace function public.get_client_dashboard_metrics(target_company uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare target_demo boolean;
begin
  if not public.is_company_member(target_company) then raise exception 'Acesso à empresa negado' using errcode='42501'; end if;
  select is_demo into target_demo from public.companies where id=target_company;
  return jsonb_build_object(
    'views',0,
    'suppliers',(select count(*) from public.companies where status='active' and is_demo=coalesce(target_demo,false)),
    'quotes',(select count(*) from public.quotes q join public.companies c on c.id=q.supplier_company_id where c.is_demo=coalesce(target_demo,false) and (q.supplier_company_id=target_company or exists(select 1 from public.opportunities o where o.id=q.opportunity_id and o.buyer_company_id=target_company))),
    'connections',(select count(*) from public.connections where status='accepted' and target_company in (buyer_company_id,supplier_company_id))
  );
end $$;

commit;
