import { NextResponse } from "next/server";
import { requireOwner } from "@/lib/auth";
import { audit, db } from "@/lib/db";
import { env } from "@/lib/env";
import { TelegramPublisher, TransistorPublisher } from "@/lib/providers/publishers";
import { R2Storage } from "@/lib/providers/r2";
import { assertSameOrigin } from "@/lib/request-security";

export async function POST(request: Request, { params }: { params: Promise<{ id: string }> }) {
  try {
    assertSameOrigin(request);
    await requireOwner();
    if (!env.PUBLISHING_ENABLED) throw new Error("Publishing safety lock is enabled");

    const { id } = await params;
    const episodes = await db()`select e.*,a.storage_key from episodes e join audio_assets a on a.episode_id=e.id and a.kind='final_mix' and a.valid=true where e.id=${id} and e.status='approved' order by a.created_at desc limit 1`;
    const e = episodes[0];
    if (!e) throw new Error("Only an approved episode with valid audio can publish");

    const key = `episode:${id}:transistor`;
    const deliveries = await db()`insert into publish_deliveries(episode_id,channel,idempotency_key)
      values(${id},'transistor',${key})
      on conflict(idempotency_key) do update set attempts=publish_deliveries.attempts+1,updated_at=now()
      returning *`;
    const delivery = deliveries[0];

    let publicUrl = delivery.public_url;
    if (delivery.status !== "published") {
      await db()`update episodes set status='publishing' where id=${id}`;
      try {
        const audioUrl = await new R2Storage().signedUrl(e.storage_key, 3600);
        const result = await new TransistorPublisher().publish({
          idempotencyKey: key,
          title: e.title,
          description: e.description,
          audioUrl,
        });
        publicUrl = result.publicUrl;
        await db()`update publish_deliveries set status='published',external_id=${result.externalId},public_url=${result.publicUrl},last_error=null,updated_at=now() where id=${delivery.id}`;
      } catch (error) {
        await db()`update publish_deliveries set status='failed',last_error=${error instanceof Error ? error.message : "Unknown error"},attempts=attempts+1,updated_at=now() where id=${delivery.id}`;
        await db()`update episodes set status='publishing',updated_at=now() where id=${id}`;
        throw error;
      }
    }

    const tgKey = `episode:${id}:telegram`;
    const telegramRows = await db()`select * from publish_deliveries where idempotency_key=${tgKey}`;
    const tg = telegramRows[0];
    if (!tg || tg.status !== "published") {
      try {
        const r = await new TelegramPublisher().publish({
          idempotencyKey: tgKey,
          title: e.title,
          caption: e.telegram_caption,
          url: publicUrl,
        });
        await db()`insert into publish_deliveries(episode_id,channel,status,idempotency_key,external_id,public_url)
          values(${id},'telegram','published',${tgKey},${r.externalId},${publicUrl})
          on conflict(idempotency_key) do update set status='published',external_id=excluded.external_id,updated_at=now()`;
      } catch (error) {
        await db()`insert into publish_deliveries(episode_id,channel,status,idempotency_key,last_error,attempts)
          values(${id},'telegram','failed',${tgKey},${error instanceof Error ? error.message : "Unknown error"},1)
          on conflict(idempotency_key) do update set attempts=publish_deliveries.attempts+1,last_error=excluded.last_error,status=excluded.status,updated_at=now()`;
        throw error;
      }
    }

    await db()`update episodes set status='published',updated_at=now() where id=${id}`;
    await audit("episode.published", "episode", id, { publicUrl });
    return NextResponse.json({ ok: true, publicUrl });
  } catch (e) {
    return NextResponse.json({ error: e instanceof Error ? e.message : "Unknown error" }, { status: 400 });
  }
}
