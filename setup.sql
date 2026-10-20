-- ============================================================
-- 万米跑活动报名投票 · 数据库建表脚本
-- 适用：Supabase (PostgreSQL 15+)
-- 用法：Supabase 控制台 → 左侧 SQL Editor → 新建查询 → 粘贴执行
-- 幂等：可重复执行，不会重复建表
-- ============================================================

-- 1. 投票明细表（追加写入，永不覆盖，保留完整改票轨迹）
create table if not exists public.votes (
  id         bigint generated always as identity primary key,
  name       text        not null,              -- 姓名 / 昵称
  dept       text        not null default '',   -- 部门 / 分组
  choice     text        not null check (choice in ('join', 'skip', 'pending')),
  note       text        not null default '',   -- 备注（如配速、距离偏好）
  created_at timestamptz not null default now()
);

-- 身份键：同一个人 = 姓名 + 部门 一致，用于改票时回显上一次结果
create index if not exists votes_identity_idx
  on public.votes (lower(btrim(name)), lower(btrim(dept)), created_at desc);

-- 2. 最新一票视图：按身份取每人最后一次提交，统计口径以此为准
create or replace view public.latest_votes as
select distinct on (lower(btrim(name)), lower(btrim(dept)))
       id, name, dept, choice, note, created_at
from public.votes
order by lower(btrim(name)), lower(btrim(dept)), created_at desc;

-- 3. 统计函数：一次请求返回各选项人数与总人数
create or replace function public.vote_stats()
returns table (choice text, cnt bigint, total bigint)
language sql
stable
as $$
  select v.choice,
         count(*)::bigint,
         (select count(*) from public.latest_votes)::bigint
  from public.latest_votes v
  group by v.choice;
$$;

-- ============================================================
-- 4. 权限策略（RLS）
--    策略说明：匿名用户只能【新增】和【读取】，不给 update / delete，
--    因此任何人都无法篡改或删除已投的票，改票以追加新纪录实现。
-- ============================================================
alter table public.votes enable row level security;

drop policy if exists "anon can insert votes" on public.votes;
create policy "anon can insert votes"
  on public.votes for insert to anon
  with check (true);

drop policy if exists "anon can read votes" on public.votes;
create policy "anon can read votes"
  on public.votes for select to anon
  using (true);

grant usage on schema public to anon;
grant select, insert on public.votes to anon;
grant select on public.latest_votes to anon;
grant execute on function public.vote_stats() to anon;

-- 5. 实时推送（可选）：看板自动刷新，无需手动刷新页面
--    若执行报错可忽略，不影响投票功能，页面会自动降级为轮询刷新。
alter publication supabase_realtime add table public.votes;

-- ============================================================
-- 常用运维 SQL
-- ------------------------------------------------------------
-- 查看当前统计：      select * from public.vote_stats();
-- 查看所有最新一票：  select * from public.latest_votes order by created_at desc;
-- 查看某人改票记录：  select * from public.votes where name = '张三' order by created_at;
-- 清空所有数据：      truncate table public.votes restart identity;
-- 导出报名名单：      select name, dept, note, created_at from public.latest_votes
--                     where choice = 'join' order by dept, name;
-- ============================================================
