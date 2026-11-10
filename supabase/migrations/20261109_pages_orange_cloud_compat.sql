-- Compatibilité avec le client Pages orange : snapshot JSONB et création d'espace personnel.
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
create policy "workspace data members select" on public.workspace_data for select to authenticated using (public.is_workspace_member(workspace_id));
create policy "workspace data members insert" on public.workspace_data for insert to authenticated with check (public.is_workspace_member(workspace_id) and updated_by = (select auth.uid()));
create policy "workspace data members update" on public.workspace_data for update to authenticated using (public.is_workspace_member(workspace_id)) with check (public.is_workspace_member(workspace_id) and updated_by = (select auth.uid()));
grant select, insert, update on public.workspace_data to authenticated;
create or replace function public.create_personal_workspace(workspace_name text default 'Mon espace Pages orange') returns uuid
language plpgsql security definer set search_path = '' as $$
declare new_workspace_id uuid;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 select wm.workspace_id into new_workspace_id from public.workspace_members wm where wm.user_id=auth.uid() order by wm.created_at asc limit 1;
 if new_workspace_id is not null then return new_workspace_id; end if;
 insert into public.workspaces(name,created_by) values(coalesce(nullif(trim(workspace_name),''),'Mon espace Pages orange'),auth.uid()) returning id into new_workspace_id;
 insert into public.workspace_members(workspace_id,user_id,role) values(new_workspace_id,auth.uid(),'owner');
 return new_workspace_id;
end; $$;
revoke all on function public.create_personal_workspace(text) from public;
grant execute on function public.create_personal_workspace(text) to authenticated;
do $$ begin
 if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='workspace_data') then alter publication supabase_realtime add table public.workspace_data; end if;
end $$;
