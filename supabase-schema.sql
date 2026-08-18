-- ═══════════════════════════════════════════════════════
-- 우리 가족 갤러리 — Supabase 초기 설정 SQL
-- Supabase 대시보드 → SQL Editor 에 붙여넣고 실행하세요.
-- (사전 준비: Storage 에서 'family-photos' 버킷을 Private 으로 먼저 만들어주세요)
-- ═══════════════════════════════════════════════════════

create table if not exists public.people (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  birthdate date,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.photos (
  id uuid primary key default gen_random_uuid(),
  storage_path text not null,
  thumb_path text not null,
  date date not null,
  year int not null,
  month int not null,
  day int not null,
  season text not null,
  title text not null default '',
  description text not null default '',
  people uuid[] not null default '{}',
  uploaded_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists photos_people_gin on public.photos using gin (people);
create index if not exists photos_date_idx on public.photos (date desc);

alter table public.people enable row level security;
alter table public.photos enable row level security;

-- 로그인한 가족 구성원(=관리자가 만들어준 계정)이면 누구나 모든 사진/사람을 보고 쓸 수 있음
drop policy if exists "family read people" on public.people;
create policy "family read people" on public.people for select using (auth.role() = 'authenticated');
drop policy if exists "family write people" on public.people;
create policy "family write people" on public.people for insert with check (auth.role() = 'authenticated');
drop policy if exists "family update people" on public.people;
create policy "family update people" on public.people for update using (auth.role() = 'authenticated');
drop policy if exists "family delete people" on public.people;
create policy "family delete people" on public.people for delete using (auth.role() = 'authenticated');

drop policy if exists "family read photos" on public.photos;
create policy "family read photos" on public.photos for select using (auth.role() = 'authenticated');
drop policy if exists "family write photos" on public.photos;
create policy "family write photos" on public.photos for insert with check (auth.role() = 'authenticated');
drop policy if exists "family update photos" on public.photos;
create policy "family update photos" on public.photos for update using (auth.role() = 'authenticated');
drop policy if exists "family delete photos" on public.photos;
create policy "family delete photos" on public.photos for delete using (auth.role() = 'authenticated');

-- Storage 버킷 'family-photos' 에 대한 접근 정책 (버킷은 대시보드에서 미리 만들어야 함)
drop policy if exists "family read photo files" on storage.objects;
create policy "family read photo files" on storage.objects for select
  using (bucket_id = 'family-photos' and auth.role() = 'authenticated');
drop policy if exists "family upload photo files" on storage.objects;
create policy "family upload photo files" on storage.objects for insert
  with check (bucket_id = 'family-photos' and auth.role() = 'authenticated');
drop policy if exists "family update photo files" on storage.objects;
create policy "family update photo files" on storage.objects for update
  using (bucket_id = 'family-photos' and auth.role() = 'authenticated');
drop policy if exists "family delete photo files" on storage.objects;
create policy "family delete photo files" on storage.objects for delete
  using (bucket_id = 'family-photos' and auth.role() = 'authenticated');
