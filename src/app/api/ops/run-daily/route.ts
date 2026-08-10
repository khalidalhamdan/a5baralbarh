import { NextResponse } from "next/server";

import { collectDaily } from "@/worker";
import { env } from "@/lib/env";

export async function POST(request: Request) {
  const token = request.headers.get("x-worker-token");
  if (!env.WORKER_TRIGGER_TOKEN || token !== env.WORKER_TRIGGER_TOKEN) {
    return NextResponse.json({ error: "invalid_worker_token" }, { status: 401 });
  }

  try {
    const episodeId = await collectDaily();
    return NextResponse.json({ ok: true, episodeId }, { status: 202 });
  } catch (error) {
    return NextResponse.json(
      { error: error instanceof Error ? error.message : "unknown_error" },
      { status: 500 }
    );
  }
}

