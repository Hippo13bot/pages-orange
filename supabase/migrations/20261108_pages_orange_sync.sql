-- Pages orange: synchronisation multi-appareils avec une ligne JSONB par espace.
-- À exécuter dans Supabase SQL Editor APRÈS le schéma initial schema.sql.
create extension if not exists pgcrypto;

-- Fonction SECURITY DEFINER pour vérifier l'appartenance sans récursion RLS.
create or replace function public.is_pages_orange_member(target_workspace uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.workspace_members wm
    where wm.workspace_id = target_workspace and wm.user_id = auth.uid()
  );
$$;
revoke all on function public.is_pages_orange_member(uuid) from public;
grant execute on function public.is_pages_orange_member(uuid) to authenticated;

-- Création atomique d'un espace personnel et de son propriétaire.
create or replace function public.create_personal_workspace(workspace_name text default 'Mon espace Pages orange')
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare new_workspace_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  select wm.workspace_id into new_workspace_id
  from public.workspace_members wm
  where wm.user_id = auth.uid()
  order by wm.created_at asc
  limit 1;

  if new_workspace_id is not null then
    return new_workspace_id;
  end if;

  insert into public.workspaces(name) values (coalesce(nullif(trim(workspace_name), ''), 'Mon espace Pages orange'))
  returning id into new_workspace_id;

  insert into public.workspace_members(workspace_id, user_id, role)
  values (new_workspace_id, auth.uid(), 'owner');

  return new_workspace_id;
end;
$$;
revoke all on function public.create_personal_workspace(text) from public;
grant execute on function public.create_personal_workspace(text) to authenticated;

-- Remplace la politique récursive de workspace_members du schéma préparatoire.
alter table public.workspaces enable row level security;
alter table public.workspace_members enable row level security;
drop policy if exists "members read workspace members" on public.workspace_members;
drop policy if exists "users see own memberships" on public.workspace_members;
drop policy if exists "workspace members read" on public.workspace_members;
create policy "workspace members read" on public.workspace_members
for select to authenticated
using (user_id = auth.uid() or public.is_pages_orange_member(workspace_id));
create policy "workspace read by members" on public.workspaces
for select to authenticated
using (public.is_pages_orange_member(id));

-- Snapshot synchronisé : contacts, entreprises, projets, relances, imports,
-- paramètres et historique relationnel. La clé primaire garantit une ligne par espace.
create table if not exists public.workspace_data (
  workspace_id uuid primary key references public.workspaces(id) on delete cascade,
  state jsonb not null default '{"contacts":[],"companies":[],"projects":[],"reminders":[],"imports":[],"settings":{"schema":1}}'::jsonb,
  updated_by uuid not null references auth.users(id),
  updated_at timestamptz not null default now()
);
alter table public.workspace_data enable row level security;
drop policy if exists "workspace data members select" on public.workspace_data;
drop policy if exists "workspace data members insert" on public.workspace_data;
drop policy if exists "workspace data members update" on public.workspace_data;
create policy "workspace data members select" on public.workspace_data
for select to authenticated using (public.is_pages_orange_member(workspace_id));
create policy "workspace data members insert" on public.workspace_data
for insert to authenticated with check (public.is_pages_orange_member(workspace_id) and updated_by = auth.uid());
create policy "workspace data members update" on public.workspace_data
for update to authenticated using (public.is_pages_orange_member(workspace_id))
with check (public.is_pages_orange_member(workspace_id) and updated_by = auth.uid());
grant select, insert, update on public.workspace_data to authenticated;

-- Active les événements Realtime pour synchroniser les autres appareils.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'workspace_data'
  ) then
    alter publication supabase_realtime add table public.workspace_data;
  end if;
exception when undefined_object then
  raise notice 'Publication supabase_realtime indisponible : la synchronisation manuelle reste active.';
end $$;
