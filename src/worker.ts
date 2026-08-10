import { createHash, randomUUID } from "node:crypto";
import { mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { audit, db } from "@/lib/db";
import { mixArgs, probeDuration, runFfmpeg } from "@/lib/audio";
import { fetchFeed } from "@/lib/rss";
import { OpenAITextProvider } from "@/lib/providers/openai";
import { ElevenLabsSpeechProvider } from "@/lib/providers/elevenlabs";
import { R2Storage } from "@/lib/providers/r2";
import type { ScriptSegment } from "@/lib/domain";

export async function collectDaily() {
  const [episode] = await db()`insert into episodes(status) values('collecting') returning *`;
  try {
    const feeds = await db()`select * from feeds where active=true order by priority desc`;
    for (const feed of feeds) {
      try {
        for (const item of await fetchFeed(feed.url)) await db()`insert into feed_items(feed_id,external_id,title,url,published_at,raw,content_hash) values(${feed.id},${item.externalId},${item.title},${item.url},${item.publishedAt},${db().json({ summary:item.summary })},${item.contentHash}) on conflict do nothing`;
        await db()`update feeds set last_fetched_at=now(),last_success_at=now(),last_error=null where id=${feed.id}`;
      } catch (error) {
        await db()`update feeds set last_fetched_at=now(),last_error=${message(error)} where id=${feed.id}`;
      }
    }
    await db()`update episodes set status='researching' where id=${episode.id}`;
    const candidates = await db()`select id,title,url,raw->>'summary' content from feed_items where published_at > now()-interval '36 hours' order by published_at desc limit 24`;
    const stories = candidates.slice(0,8).map((item:any)=>({ id:item.id,title:item.title,content:item.content,sources:[item.url],sensitive:false }));
    if (!stories.length) throw new Error("No eligible stories found");
    await db()`update episodes set status='scripting' where id=${episode.id}`;
    const generated = await new OpenAITextProvider().createEpisode({ stories, targetSeconds:600 });
    const [script] = await db()`insert into scripts(episode_id,version,content) values(${episode.id},1,${db().json(generated)}) returning *`;
    for (const [position,segment] of generated.segments.entries()) await db()`insert into script_segments(id,script_id,speaker,position,text,source_urls,pronunciation_notes) values(${segment.id},${script.id},${segment.speaker},${position},${segment.text},${db().json(segment.sourceUrls)},${db().json(segment.pronunciationNotes)})`;
    await db()`update episodes set title=${generated.title},description=${generated.description},summary=${generated.summary},telegram_caption=${generated.telegramCaption},estimated_seconds=${Math.round(generated.estimatedSeconds)},status='synthesizing',updated_at=now() where id=${episode.id}`;
    await audit("episode.scripted","episode",episode.id,{ stories:stories.length,segments:generated.segments.length });
    await synthesizeAndMix(episode.id, script.id, generated.segments);
    return episode.id;
  } catch (error) {
    await db()`update episodes set status='failed',last_error=${message(error)},updated_at=now() where id=${episode.id}`;
    throw error;
  }
}

export async function synthesizeAndMix(episodeId:string,scriptId:string,segments:ScriptSegment[]) {
  const work = await mkdtemp(path.join(tmpdir(),"najdi-podcast-"));
  const storage = new R2Storage(), speech = new ElevenLabsSpeechProvider();
  try {
    const files:string[]=[];
    for (const [position,segment] of segments.entries()) {
      const file=path.join(work,`${String(position).padStart(3,"0")}.mp3`), key=`episodes/${episodeId}/segments/${segment.id}.mp3`;
      const [existing]=await db()`select a.* from script_segments s join audio_assets a on a.id=s.audio_asset_id where s.script_id=${scriptId} and s.id=${segment.id} and a.valid=true`;
      if (existing) await download(await storage.signedUrl(existing.storage_key,900),file);
      else {
        const meta=await speech.synthesize({ text:segment.text,speaker:segment.speaker,outputPath:file });
        const bytes=await readFile(file),checksum=sha(bytes);await storage.put(key,bytes,"audio/mpeg");
        const [asset]=await db()`insert into audio_assets(episode_id,kind,storage_key,content_type,checksum,provider,model,voice_id) values(${episodeId},'segment',${key},'audio/mpeg',${checksum},${meta.provider},${meta.model},${meta.voiceId}) returning id`;
        await db()`update script_segments set audio_asset_id=${asset.id} where script_id=${scriptId} and id=${segment.id}`;
      }
      files.push(file);
    }
    const list=path.join(work,"segments.txt");await writeFile(list,files.map(file=>`file '${file.replaceAll("'","'\\''")}'`).join("\n"));
    const speechOnly=path.join(work,"speech.mp3");await runFfmpeg(["-y","-f","concat","-safe","0","-i",list,"-c:a","libmp3lame","-b:a","128k",speechOnly]);
    const speechBytes=await readFile(speechOnly),speechKey=`episodes/${episodeId}/speech.mp3`;await storage.put(speechKey,speechBytes,"audio/mpeg");
    await db()`insert into audio_assets(episode_id,kind,storage_key,content_type,checksum) values(${episodeId},'speech_only',${speechKey},'audio/mpeg',${sha(speechBytes)})`;
    await db()`update episodes set status='mixing',updated_at=now() where id=${episodeId}`;
    const [music]=await db()`select * from music_tracks where is_default=true and rights_confirmed=true order by created_at desc limit 1`;
    if (!music) throw new Error("A rights-confirmed default music track is required");
    const musicFile=path.join(work,"music-input");await download(await storage.signedUrl(music.storage_key,900),musicFile);
    const duration=await probeDuration(speechOnly),finalFile=path.join(work,"final.mp3");await runFfmpeg(mixArgs(speechOnly,musicFile,finalFile,duration));
    const finalBytes=await readFile(finalFile),finalKey=`episodes/${episodeId}/final.mp3`,checksum=sha(finalBytes);await storage.put(finalKey,finalBytes,"audio/mpeg");
    const [asset]=await db()`insert into audio_assets(episode_id,kind,storage_key,content_type,duration_seconds,checksum) values(${episodeId},'final_mix',${finalKey},'audio/mpeg',${duration},${checksum}) returning id`;
    await db()`insert into mix_versions(episode_id,version,music_track_id,parameters,output_asset_id) values(${episodeId},1,${music.id},${db().json({ speechLufs:-16,musicVolume:.1,limiter:.95 })},${asset.id})`;
    await db()`update episodes set status='needs_review',estimated_seconds=${Math.round(duration)},audio_checksum=${checksum},last_error=null,updated_at=now() where id=${episodeId}`;
    await audit("episode.ready_for_review","episode",episodeId,{ duration,checksum,segments:segments.length });
  } finally { await rm(work,{ recursive:true,force:true }); }
}

async function download(url:string,file:string){const response=await fetch(url);if(!response.ok)throw new Error(`Media download failed: ${response.status}`);await writeFile(file,Buffer.from(await response.arrayBuffer()))}
function sha(bytes:Uint8Array){return createHash("sha256").update(bytes).digest("hex")}
function message(error:unknown){return error instanceof Error?error.message:"Unknown error"}
if(process.argv[1]?.endsWith("worker.ts"))collectDaily().then(id=>{console.log(`Created episode ${id}`);process.exit(0)}).catch(error=>{console.error(error);process.exit(1)});
