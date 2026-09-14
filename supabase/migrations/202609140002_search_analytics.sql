begin;
create table if not exists public.search_events(
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade default auth.uid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  search_term text not null check(length(trim(search_term)) between 3 and 180),
  product_name text not null check(length(trim(product_name)) between 2 and 180),
  is_demo boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists search_events_popular_idx on public.search_events(is_demo,product_name,created_at desc);
alter table public.search_events enable row level security;
create policy search_events_self_read on public.search_events for select to authenticated using(user_id=auth.uid() or public.is_super_admin());
create policy search_events_self_insert on public.search_events for insert to authenticated with check(user_id=auth.uid() and public.is_company_member(company_id) and is_demo=public.is_demo_user());
grant select,insert on public.search_events to authenticated;

create or replace function public.record_product_search(target_company uuid,term text,selected_product text) returns void
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.is_company_member(target_company) then raise exception 'Acesso negado' using errcode='42501'; end if;
 if length(trim(term))<3 or length(trim(selected_product))<2 then raise exception 'Busca inválida'; end if;
 insert into public.search_events(user_id,company_id,search_term,product_name,is_demo)
 values(auth.uid(),target_company,left(trim(term),180),left(trim(selected_product),180),public.is_demo_user());
end$$;
create or replace function public.get_most_searched_products(result_limit integer default 20)
returns table(product_name text,searches bigint,last_searched_at timestamptz)
language sql stable security definer set search_path='' as $$
 select e.product_name,count(*) searches,max(e.created_at) last_searched_at
 from public.search_events e where auth.uid() is not null and e.is_demo=public.is_demo_user()
 group by e.product_name order by searches desc,last_searched_at desc
 limit least(greatest(result_limit,1),50)
$$;
revoke all on function public.record_product_search(uuid,text,text),public.get_most_searched_products(integer) from public;
grant execute on function public.record_product_search(uuid,text,text),public.get_most_searched_products(integer) to authenticated;
commit;
