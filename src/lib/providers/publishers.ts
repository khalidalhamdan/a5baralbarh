import { env } from "@/lib/env";
import type { MessagePublisher, PodcastPublisher } from "@/lib/domain";
export class TransistorPublisher implements PodcastPublisher {
  private headers(){if(!env.TRANSISTOR_API_KEY)throw new Error("TRANSISTOR_API_KEY is missing");return {"x-api-key":env.TRANSISTOR_API_KEY,"content-type":"application/x-www-form-urlencoded"}}
  async publish(input:Parameters<PodcastPublisher["publish"]>[0]){
    if(!env.PUBLISHING_ENABLED)throw new Error("Publishing safety lock is enabled"); if(!env.TRANSISTOR_SHOW_ID)throw new Error("TRANSISTOR_SHOW_ID is missing");
    const auth=this.headers(); const upload=await fetch("https://api.transistor.fm/v1/episodes/authorize_upload",{headers:auth}); if(!upload.ok)throw new Error(`Transistor upload authorization failed: ${upload.status}`);
    const info=await upload.json() as {data:{attributes:{upload_url:string,audio_url:string}}}; const audio=await fetch(input.audioUrl); if(!audio.ok)throw new Error("Could not read approved audio");
    const put=await fetch(info.data.attributes.upload_url,{method:"PUT",body:await audio.arrayBuffer()}); if(!put.ok)throw new Error(`Transistor media upload failed: ${put.status}`);
    const params=new URLSearchParams({"episode[show_id]":env.TRANSISTOR_SHOW_ID,"episode[title]":input.title,"episode[description]":input.description,"episode[audio_url]":info.data.attributes.audio_url,"episode[status]":"published"});
    const created=await fetch("https://api.transistor.fm/v1/episodes",{method:"POST",headers:{...auth,"Idempotency-Key":input.idempotencyKey},body:params}); if(!created.ok)throw new Error(`Transistor create failed: ${created.status} ${await created.text()}`);
    const json=await created.json() as {data:{id:string;attributes:{share_url:string;media_url:string}}}; return {externalId:json.data.id,publicUrl:json.data.attributes.share_url,enclosureUrl:json.data.attributes.media_url};
  }
  async unpublish(id:string){const r=await fetch(`https://api.transistor.fm/v1/episodes/${id}/publish`,{method:"PATCH",headers:this.headers(),body:new URLSearchParams({"episode[status]":"draft"})});if(!r.ok)throw new Error(`Unpublish failed: ${r.status}`)}
}
export class TelegramPublisher implements MessagePublisher {async publish(input:Parameters<MessagePublisher["publish"]>[0]){if(!env.PUBLISHING_ENABLED)throw new Error("Publishing safety lock is enabled");if(!env.TELEGRAM_BOT_TOKEN||!env.TELEGRAM_CHAT_ID)throw new Error("Telegram is not configured");const r=await fetch(`https://api.telegram.org/bot${env.TELEGRAM_BOT_TOKEN}/sendMessage`,{method:"POST",headers:{"content-type":"application/json"},body:JSON.stringify({chat_id:env.TELEGRAM_CHAT_ID,text:`*${escape(input.title)}*\n\n${escape(input.caption)}\n\n${input.url}`,parse_mode:"MarkdownV2",disable_web_page_preview:false})});if(!r.ok)throw new Error(`Telegram failed: ${r.status} ${await r.text()}`);const j=await r.json() as {result:{message_id:number}};return {externalId:String(j.result.message_id)}}}
function escape(v:string){return v.replace(/[_*\[\]()~`>#+\-=|{}.!]/g,"\\$&")}
