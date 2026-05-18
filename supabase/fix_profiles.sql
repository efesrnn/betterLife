CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique not null,
  habit text,
  goal text
);
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
