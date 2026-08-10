import { writeFile } from "node:fs/promises";
import { env } from "@/lib/env";
import type { SpeechProvider } from "@/lib/domain";
export class ElevenLabsSpeechProvider implements SpeechProvider {
  async synthesize({text,speaker,outputPath}:Parameters<SpeechProvider["synthesize"]>[0]){
    const voiceId=speaker==="host_a"?env.ELEVENLABS_HOST_A_VOICE_ID:env.ELEVENLABS_HOST_B_VOICE_ID;
    if(!env.ELEVENLABS_API_KEY||!voiceId)throw new Error(`ElevenLabs voice is not configured for ${speaker}`);
    const res=await fetch(`https://api.elevenlabs.io/v1/text-to-speech/${voiceId}`,{method:"POST",headers:{"xi-api-key":env.ELEVENLABS_API_KEY,"content-type":"application/json","accept":"audio/mpeg"},body:JSON.stringify({text,model_id:"eleven_multilingual_v2",voice_settings:{stability:.55,similarity_boost:.75,style:.25,use_speaker_boost:true}})});
    if(!res.ok)throw new Error(`ElevenLabs ${res.status}: ${await res.text()}`);
    await writeFile(outputPath,Buffer.from(await res.arrayBuffer())); return {provider:"elevenlabs",model:"eleven_multilingual_v2",voiceId};
  }
}
