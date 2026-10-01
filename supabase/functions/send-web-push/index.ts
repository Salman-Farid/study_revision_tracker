// Production Web Push sender for daily-routine blocks (idempotent).
import { createClient } from "npm:@supabase/supabase-js@2";
import webpush from "npm:web-push@3.6.7";

const VAPID_PUBLIC = Deno.env.get("WEB_PUSH_VAPID_PUBLIC")!;
const VAPID_PRIVATE = Deno.env.get("WEB_PUSH_VAPID_PRIVATE")!;
const CRON_SECRET = Deno.env.get("WEB_PUSH_CRON_SECRET")!;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

webpush.setVapidDetails(
  "mailto:notifications@pootustudycompanion.xyz",
  VAPID_PUBLIC,
  VAPID_PRIVATE,
);

type SubRow = {
  endpoint: string;
  p256dh: string;
  auth: string;
  timezone_offset_minutes?: number | null;
  user_id: string;
};

type Block = {
  time: string;
  subject?: string;
  topic?: string;
  type?: string;
  duration_minutes?: number;
};

function localHhmmDay(offsetMin: number): { hhmm: string; dayKey: string } {
  const now = new Date(Date.now() + offsetMin * 60_000);
  const hh = String(now.getUTCHours()).padStart(2, "0");
  const mm = String(now.getUTCMinutes()).padStart(2, "0");
  const y = now.getUTCFullYear();
  const mo = String(now.getUTCMonth() + 1).padStart(2, "0");
  const d = String(now.getUTCDate()).padStart(2, "0");
  return { hhmm: `${hh}:${mm}`, dayKey: `${y}-${mo}-${d}` };
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("method", { status: 405 });
  const secret = req.headers.get("x-cron-secret") ?? "";
  if (!CRON_SECRET || secret !== CRON_SECRET) {
    return new Response("forbidden", { status: 403 });
  }

  const sb = createClient(SUPABASE_URL, SERVICE_ROLE, {
    auth: { persistSession: false },
  });

  const { data: subs, error: subErr } = await sb
    .from("push_subscriptions")
    .select("endpoint,p256dh,auth,timezone_offset_minutes,user_id");
  if (subErr) return new Response(subErr.message, { status: 500 });
  const subRows = (subs ?? []) as SubRow[];
  if (subRows.length === 0) {
    return json({ sent: 0, note: "no subscriptions" });
  }

  const { data: routines, error: rErr } = await sb
    .from("daily_routines")
    .select("id,user_id,date,items");
  if (rErr) return new Response(rErr.message, { status: 500 });

  let sent = 0;
  for (const sub of subRows) {
    const offset = sub.timezone_offset_minutes ?? 360;
    const { hhmm, dayKey } = localHhmmDay(offset);
    for (const routine of (routines ?? []) as Array<{
      id: string;
      user_id: string;
      date: string;
      items: unknown;
    }>) {
      if (routine.user_id !== sub.user_id) continue;
      if (String(routine.date).slice(0, 10) !== dayKey) continue;
      let items: Block[] = [];
      try {
        items =
          typeof routine.items === "string"
            ? JSON.parse(routine.items)
            : (routine.items as Block[]);
      } catch {
        continue;
      }
      for (let i = 0; i < items.length; i++) {
        const block = items[i] ?? {};
        const time = String(block.time ?? "");
        const blockHm = time.length >= 5 ? time.slice(0, 5) : "";
        if (blockHm !== hhmm) continue;
        const blockKey = `${routine.id}:${dayKey}:${i}`;
        const { data: already } = await sb
          .from("push_send_log")
          .select("id")
          .eq("endpoint", sub.endpoint)
          .eq("block_key", blockKey)
          .maybeSingle();
        if (already) continue;
        const label = block.subject || block.type || "Study";
        const topic = block.topic ? `: ${block.topic}` : "";
        try {
          await webpush.sendNotification(
            {
              endpoint: sub.endpoint,
              keys: { p256dh: sub.p256dh, auth: sub.auth },
            },
            JSON.stringify({
              title: `📋 ${label}${topic}`,
              body: `${blockHm} — ${block.duration_minutes ?? ""} min block`,
              tag: blockKey,
              url: "/home",
            }),
            { TTL: 3600, urgency: "high" },
          );
          await sb.from("push_send_log").upsert(
            { endpoint: sub.endpoint, block_key: blockKey },
            { onConflict: "endpoint,block_key" },
          );
          sent++;
        } catch (err) {
          const status = (err as { statusCode?: number })?.statusCode;
          if (status === 404 || status === 410) {
            await sb.from("push_subscriptions").delete().eq("endpoint", sub.endpoint);
          }
        }
      }
    }
  }
  return json({ sent, subs: subRows.length });
});

function json(o: unknown) {
  return new Response(JSON.stringify(o), {
    status: 200,
    headers: { "content-type": "application/json" },
  });
}
