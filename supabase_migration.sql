-- ═══════════════════════════════════════════════════════════════════
-- Wink VPN — таблица профилей пользователей
-- Выполнить в Supabase Dashboard → SQL Editor → New query → Run
-- ═══════════════════════════════════════════════════════════════════

-- Последовательность для 5-значных ID пользователей (10000, 10001, 10002...)
create sequence if not exists public.user_number_seq start with 10000 increment by 1;

-- Таблица профилей — одна строка на пользователя, привязана к auth.users
create table if not exists public.profiles (
  id uuid references auth.users on delete cascade primary key,
  user_number bigint unique not null default nextval('public.user_number_seq'),
  email text,
  nickname text,
  language text not null default 'ru',
  created_at timestamptz not null default now()
);

-- Функция: при регистрации нового пользователя автоматически создаём профиль
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, email, nickname, language)
  values (
    new.id,
    new.email,
    split_part(coalesce(new.email, 'user'), '@', 1),
    'ru'
  )
  on conflict (id) do nothing;
  return new;
end;
$$ language plpgsql security definer set search_path = public;

-- Триггер: срабатывает сразу после создания записи в auth.users
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- Row Level Security — каждый видит и меняет только свою запись
alter table public.profiles enable row level security;

drop policy if exists "Users can view own profile" on public.profiles;
create policy "Users can view own profile"
  on public.profiles for select
  using (auth.uid() = id);

drop policy if exists "Users can update own profile" on public.profiles;
create policy "Users can update own profile"
  on public.profiles for update
  using (auth.uid() = id);

-- ═══════════════════════════════════════════════════════════════════
-- Готово. Проверить: Table Editor → profiles — таблица должна появиться.
-- Как только кто-то войдёт через Google, строка создастся автоматически.
-- ═══════════════════════════════════════════════════════════════════

