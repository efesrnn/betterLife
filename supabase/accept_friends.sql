-- ============================================================
-- Bekleyen istekleri + mock arkadaşlıkları ANINDA kabul et.
-- Supabase → SQL Editor → yapıştır → Run. Sonra leaderboard'ı aşağı çek (yenile).
-- ============================================================

-- 1) Gönderdiğin / sana gelen TÜM bekleyen istekleri kabul et.
--    (Mock'lar kendileri kabul edemediği için pending kalıyordu.)
update public.friendships
set status = 'ACCEPTED', updated_at = now()
where status = 'PENDING';

-- 2) Hiç istek atmadığın mock'lar varsa, onlarla da doğrudan ACCEPTED arkadaşlık ekle.
insert into public.friendships (requester_id, addressee_id, status)
select p.id, m.id, 'ACCEPTED'
from public.profiles p
cross join (values
  ('0a000001-0000-4000-a000-000000000001'::uuid),
  ('0a000002-0000-4000-a000-000000000002'::uuid),
  ('0a000003-0000-4000-a000-000000000003'::uuid),
  ('0a000004-0000-4000-a000-000000000004'::uuid),
  ('0a000005-0000-4000-a000-000000000005'::uuid)
) as m(id)
where p.id <> m.id
  and p.id not in (
    '0a000001-0000-4000-a000-000000000001',
    '0a000002-0000-4000-a000-000000000002',
    '0a000003-0000-4000-a000-000000000003',
    '0a000004-0000-4000-a000-000000000004',
    '0a000005-0000-4000-a000-000000000005'
  )
on conflict (requester_id, addressee_id) do nothing;

-- Kontrol: kaç arkadaşlığın ACCEPTED?
select status, count(*) from public.friendships group by status;
