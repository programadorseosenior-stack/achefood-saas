-- AcheFood SaaS V1 — indicadores reais dos dashboards.
-- Expõe somente agregados e valida autorização dentro das funções.

create or replace function public.get_admin_dashboard_metrics()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.is_super_admin() then
    raise exception 'Acesso administrativo negado' using errcode = '42501';
  end if;

  return jsonb_build_object(
    'companies', (select count(*) from public.companies),
    'suppliers', (
      select count(distinct cm.user_id)
      from public.company_members cm
      join public.profiles p on p.id = cm.user_id
      where cm.status = 'active' and p.profile_type in ('supplier', 'both')
    ),
    'buyers', (
      select count(distinct cm.user_id)
      from public.company_members cm
      join public.profiles p on p.id = cm.user_id
      where cm.status = 'active' and p.profile_type in ('buyer', 'both')
    ),
    'products', 0
  );
end;
$$;

create or replace function public.get_client_dashboard_metrics(target_company uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.is_company_member(target_company) then
    raise exception 'Acesso à empresa negado' using errcode = '42501';
  end if;

  return jsonb_build_object(
    'views', 0,
    'suppliers', (
      select count(distinct cm.user_id)
      from public.company_members cm
      join public.profiles p on p.id = cm.user_id
      where cm.status = 'active' and p.profile_type in ('supplier', 'both')
    ),
    'quotes', 0,
    'connections', 0
  );
end;
$$;

revoke all on function public.get_admin_dashboard_metrics() from public;
revoke all on function public.get_client_dashboard_metrics(uuid) from public;
grant execute on function public.get_admin_dashboard_metrics() to authenticated;
grant execute on function public.get_client_dashboard_metrics(uuid) to authenticated;
