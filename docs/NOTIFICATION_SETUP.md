# Push Bildirim Kurulumu (FCM)

Uygulama tarafi hazir. Cihaz, acilista bildirim izni istiyor, FCM token'ini alip
Supabase'deki `device_tokens` tablosuna yaziyor. Asagidaki adimlar sunucu tarafini
tamamlamak icin gerekli.

## 1. Veritabani tablosu

Supabase SQL editorunde calistir:

```sql
create table if not exists public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  token text not null unique,
  platform text,
  updated_at timestamptz default now()
);

alter table public.device_tokens enable row level security;

-- Herkes yalnizca kendi token kayitlarini yonetebilir
create policy "kendi tokenini ekle" on public.device_tokens
  for insert with check (auth.uid() = user_id);
create policy "kendi tokenini guncelle" on public.device_tokens
  for update using (auth.uid() = user_id);
create policy "kendi tokenini sil" on public.device_tokens
  for delete using (auth.uid() = user_id);
create policy "kendi tokenini gor" on public.device_tokens
  for select using (auth.uid() = user_id);
```

## 2. Firebase servis hesabi anahtari

Bildirimi sunucudan gondermek icin FCM HTTP v1 API kullanilir, bunun icin de
servis hesabi anahtari gerekir:

1. Firebase Console > Proje ayarlari > Service accounts
2. "Generate new private key" ile JSON dosyasini indir
3. Supabase'de sakla: `supabase secrets set FCM_SERVICE_ACCOUNT="$(cat anahtar.json)"`

## 3. Bildirim gonderen edge function

`supabase/functions/send-push/index.ts` olarak deploy edilebilir ornek:

```ts
import { JWT } from "npm:google-auth-library@9";
import { createClient } from "npm:@supabase/supabase-js@2";

const serviceAccount = JSON.parse(Deno.env.get("FCM_SERVICE_ACCOUNT")!);

async function getAccessToken(): Promise<string> {
  const jwt = new JWT({
    email: serviceAccount.client_email,
    key: serviceAccount.private_key,
    scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
  });
  const { access_token } = await jwt.authorize();
  return access_token!;
}

Deno.serve(async (req) => {
  // Beklenen govde: { user_id: "...", title: "...", body: "..." }
  const { user_id, title, body } = await req.json();

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const { data: tokens } = await admin
    .from("device_tokens")
    .select("token")
    .eq("user_id", user_id);

  if (!tokens || tokens.length === 0) {
    return Response.json({ sent: 0, reason: "no_tokens" });
  }

  const accessToken = await getAccessToken();
  let sent = 0;

  for (const { token } of tokens) {
    const res = await fetch(
      `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          message: {
            token,
            notification: { title, body },
            android: {
              notification: { channel_id: "better_life_general" },
            },
          },
        }),
      },
    );
    if (res.ok) {
      sent++;
    } else if (res.status === 404 || res.status === 410) {
      // Gecersiz token, temizle
      await admin.from("device_tokens").delete().eq("token", token);
    }
  }

  return Response.json({ sent });
});
```

Deploy: `supabase functions deploy send-push`

## 4. Hizli test

Edge function olmadan da test edebilirsin: Firebase Console > Messaging >
"Create your first campaign" ile test bildirimi gonder. Token'i uygulama loglarinda
gormek istersen `NotificationService.syncToken` icine gecici bir `debugPrint` ekle.

## Notlar

- Android tarafinda baska ek adim yok, `google-services.json` zaten projede.
- iOS icin Apple Developer hesabi, APNs anahtari ve `GoogleService-Info.plist` gerekir.
- Gunluk hatirlatma gibi zamanlanmis bildirimler icin Supabase'de `pg_cron` ile
  edge function tetiklenebilir.
