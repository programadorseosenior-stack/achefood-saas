begin;

alter table public.profiles add column if not exists email text;
alter table public.profiles add column if not exists full_name text;
alter table public.profiles add column if not exists role text not null default 'buyer'
  check (role in ('buyer','supplier','company_owner','admin','super_admin'));
alter table public.profiles add column if not exists status text not null default 'active'
  check (status in ('pending_password','active','suspended'));
alter table public.profiles add column if not exists first_access_completed_at timestamptz;

create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path='' as $$
declare is_initial_admin boolean := lower(new.email) = 'achefood91@gmail.com';
begin
  insert into public.profiles(id,email,first_name,last_name,full_name,profile_type,role,status)
  values(
    new.id,lower(new.email),new.raw_user_meta_data->>'first_name',new.raw_user_meta_data->>'last_name',
    nullif(trim(coalesce(new.raw_user_meta_data->>'full_name',new.raw_user_meta_data->>'name','')),''),
    case when new.raw_user_meta_data->>'profile_type' in ('buyer','supplier','both') then (new.raw_user_meta_data->>'profile_type')::public.profile_type else null end,
    case when is_initial_admin then 'super_admin' else 'buyer' end,
    case when is_initial_admin then 'pending_password' else 'active' end
  ) on conflict(id) do update set email=excluded.email;
  if is_initial_admin then
    insert into public.admin_members(user_id,role,status) values(new.id,'super_admin','pending')
    on conflict(user_id) do update set role='super_admin',status='pending';
  end if;
  return new;
end $$;

create policy admin_members_self_select on public.admin_members for select to authenticated
using (user_id = (select auth.uid()));

grant select on public.admin_members to authenticated;
revoke update on public.profiles from authenticated;
grant update(first_name,last_name,phone,profile_type,onboarding_completed,full_name) on public.profiles to authenticated;

create or replace function public.complete_admin_first_access() returns void
language plpgsql security definer set search_path='' as $$
declare uid uuid := auth.uid(); verified_email text;
begin
  if uid is null then raise exception 'Autenticação necessária' using errcode='42501'; end if;
  select lower(email) into verified_email from auth.users where id=uid and email_confirmed_at is not null;
  if verified_email is distinct from 'achefood91@gmail.com' then raise exception 'Acesso não autorizado' using errcode='42501'; end if;
  if not exists(select 1 from public.admin_members where user_id=uid and role='super_admin' and status='pending') then
    raise exception 'Convite de primeiro acesso inválido' using errcode='42501';
  end if;
  update public.admin_members set status='active' where user_id=uid;
  update public.profiles set role='super_admin',status='active',first_access_completed_at=now() where id=uid;
  insert into public.audit_logs(actor_id,action,entity_type,entity_id,new_value)
  values(uid,'admin_first_access_completed','profile',uid::text,jsonb_build_object('role','super_admin'));
end $$;

revoke all on function public.complete_admin_first_access() from public;
grant execute on function public.complete_admin_first_access() to authenticated;

commit;
