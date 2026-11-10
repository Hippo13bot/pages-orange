-- Pages orange: schéma de base multi-tenant initial. À faire relire avant production.
create extension if not exists pgcrypto;
create table if not exists public.workspaces(
 id uuid primary key default gen_random_uuid(), name text not null,
 created_at timestamptz not null default now()
);
create table if not exists public.workspace_members(
 workspace_id uuid not null references public.workspaces(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 role text not null default 'owner' check(role in ('owner','admin','member','viewer')),
 created_at timestamptz not null default now(), primary key(workspace_id,user_id)
);
create table if not exists public.contacts(
 id uuid primary key default gen_random_uuid(),
 workspace_id uuid not null references public.workspaces(id) on delete cascade,
 created_by uuid not null references auth.users(id),
 first_name text, last_name text, job_title text, company text, email text, phone text,
 instagram text, linkedin text, website text, city text, priority text default 'normal',
 notes text, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.tags(
 id uuid primary key default gen_random_uuid(), workspace_id uuid not null references public.workspaces(id) on delete cascade,
 name text not null, unique(workspace_id,name)
);
create table if not exists public.contact_tags(
 contact_id uuid not null references public.contacts(id) on delete cascade,
 tag_id uuid not null references public.tags(id) on delete cascade,
 primary key(contact_id,tag_id)
);
create table if not exists public.companies(
 id uuid primary key default gen_random_uuid(), workspace_id uuid not null references public.workspaces(id) on delete cascade,
 name text not null, website text, city text, notes text, created_at timestamptz default now()
);
create table if not exists public.projects(
 id uuid primary key default gen_random_uuid(), workspace_id uuid not null references public.workspaces(id) on delete cascade,
 name text not null, project_type text, project_date date, notes text, created_at timestamptz default now()
);
create table if not exists public.project_contacts(
 project_id uuid not null references public.projects(id) on delete cascade,
 contact_id uuid not null references public.contacts(id) on delete cascade,
 primary key(project_id,contact_id)
);
create table if not exists public.interactions(
 id uuid primary key default gen_random_uuid(), workspace_id uuid not null references public.workspaces(id) on delete cascade,
 contact_id uuid not null references public.contacts(id) on delete cascade,
 channel text, direction text, occurred_at timestamptz, summary text, source_ref text, created_at timestamptz default now()
);
create table if not exists public.imports(
 id uuid primary key default gen_random_uuid(), workspace_id uuid not null references public.workspaces(id) on delete cascade,
 created_by uuid not null references auth.users(id), source_type text not null, file_name text,
 status text not null default 'pending', extracted_text text, created_at timestamptz default now()
);
create table if not exists public.reminders(
 id uuid primary key default gen_random_uuid(), workspace_id uuid not null references public.workspaces(id) on delete cascade,
 contact_id uuid references public.contacts(id) on delete cascade, title text not null,
 due_at timestamptz, completed_at timestamptz, created_at timestamptz default now()
);
-- RLS: membership-based read/write; role-based write restrictions should be refined before production.
do $$ declare t text; begin
 foreach t in array array['workspace_members','contacts','tags','contact_tags','companies','projects','project_contacts','interactions','imports','reminders'] loop
  execute format('alter table public.%I enable row level security',t);
 end loop;
end $$;
create policy "members read workspace members" on public.workspace_members for select using (
 exists(select 1 from public.workspace_members m where m.workspace_id=workspace_members.workspace_id and m.user_id=auth.uid())
);
create policy "users see own memberships" on public.workspace_members for insert with check(user_id=auth.uid());
create policy "contacts workspace access" on public.contacts for all using (
 exists(select 1 from public.workspace_members m where m.workspace_id=contacts.workspace_id and m.user_id=auth.uid())
) with check (
 exists(select 1 from public.workspace_members m where m.workspace_id=contacts.workspace_id and m.user_id=auth.uid())
);
create policy "tags workspace access" on public.tags for all using (
 exists(select 1 from public.workspace_members m where m.workspace_id=tags.workspace_id and m.user_id=auth.uid())
) with check (
 exists(select 1 from public.workspace_members m where m.workspace_id=tags.workspace_id and m.user_id=auth.uid())
);
create policy "companies workspace access" on public.companies for all using (
 exists(select 1 from public.workspace_members m where m.workspace_id=companies.workspace_id and m.user_id=auth.uid())
) with check (
 exists(select 1 from public.workspace_members m where m.workspace_id=companies.workspace_id and m.user_id=auth.uid())
);
create policy "projects workspace access" on public.projects for all using (
 exists(select 1 from public.workspace_members m where m.workspace_id=projects.workspace_id and m.user_id=auth.uid())
) with check (
 exists(select 1 from public.workspace_members m where m.workspace_id=projects.workspace_id and m.user_id=auth.uid())
);
create policy "interactions workspace access" on public.interactions for all using (
 exists(select 1 from public.workspace_members m where m.workspace_id=interactions.workspace_id and m.user_id=auth.uid())
) with check (
 exists(select 1 from public.workspace_members m where m.workspace_id=interactions.workspace_id and m.user_id=auth.uid())
);
create policy "imports workspace access" on public.imports for all using (
 exists(select 1 from public.workspace_members m where m.workspace_id=imports.workspace_id and m.user_id=auth.uid())
) with check (
 exists(select 1 from public.workspace_members m where m.workspace_id=imports.workspace_id and m.user_id=auth.uid())
);
create policy "reminders workspace access" on public.reminders for all using (
 exists(select 1 from public.workspace_members m where m.workspace_id=reminders.workspace_id and m.user_id=auth.uid())
) with check (
 exists(select 1 from public.workspace_members m where m.workspace_id=reminders.workspace_id and m.user_id=auth.uid())
);
-- Important: policies for contact_tags and project_contacts must validate that BOTH linked rows
-- belong to the same workspace. Add hardened join policies before production use.
