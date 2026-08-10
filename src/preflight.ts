import { spawn } from "node:child_process";
import { db } from "@/lib/db";
import { R2Storage } from "@/lib/providers/r2";

type Check={name:string;ok:boolean;detail:string};
const checks:Check[]=[];
async function check(name:string,run:()=>Promise<string>){try{checks.push({name,ok:true,detail:await run()})}catch(error){checks.push({name,ok:false,detail:error instanceof Error?error.message:"Unknown error"})}}
function required(name:string){const value=process.env[name];if(!value)throw new Error(`${name} is missing`);return value}

await check("PostgreSQL",async()=>{await db()`select 1`;return"connection and query succeeded"});
await check("FFmpeg",async()=>new Promise((resolve,reject)=>{const child=spawn("ffmpeg",["-version"],{stdio:["ignore","pipe","ignore"]});let first="";child.stdout.on("data",chunk=>{if(!first)first=String(chunk).split("\n")[0]});child.on("error",reject);child.on("exit",code=>code===0?resolve(first):reject(new Error(`ffmpeg exited ${code}`)))}));
await check("Cloudflare R2",async()=>{await new R2Storage().healthcheck();return"private bucket is reachable"});
await check("OpenAI",async()=>{const key=required("OPENAI_API_KEY"),response=await fetch("https://api.openai.com/v1/models",{headers:{authorization:`Bearer ${key}`}});if(!response.ok)throw new Error(`OpenAI returned ${response.status}`);return"API key accepted"});
for(const [host,keyName] of [["Host A","ELEVENLABS_HOST_A_VOICE_ID"],["Host B","ELEVENLABS_HOST_B_VOICE_ID"]] as const)await check(`ElevenLabs ${host}`,async()=>{const key=required("ELEVENLABS_API_KEY"),voice=required(keyName),response=await fetch(`https://api.elevenlabs.io/v1/voices/${voice}`,{headers:{"xi-api-key":key}});if(!response.ok)throw new Error(`ElevenLabs returned ${response.status}`);return`voice ${voice.slice(0,4)}… is available`});
await check("Transistor",async()=>{const key=required("TRANSISTOR_API_KEY"),show=required("TRANSISTOR_SHOW_ID"),response=await fetch(`https://api.transistor.fm/v1/shows/${show}`,{headers:{"x-api-key":key}});if(!response.ok)throw new Error(`Transistor returned ${response.status}`);return"show and API key accepted"});
await check("Telegram",async()=>{const token=required("TELEGRAM_BOT_TOKEN"),chat=required("TELEGRAM_CHAT_ID"),response=await fetch(`https://api.telegram.org/bot${token}/getMe`);if(!response.ok)throw new Error(`Telegram returned ${response.status}`);return`bot accepted; staging chat configured (${chat.slice(0,3)}…)`});
await check("Publishing safety",async()=>process.env.PUBLISHING_ENABLED==="true"?Promise.reject(new Error("PUBLISHING_ENABLED must remain false for preflight")):"public publishing remains disabled");

console.table(checks);const failed=checks.filter(item=>!item.ok);if(failed.length){console.error(`Preflight failed: ${failed.length}/${checks.length} checks require attention.`);process.exit(1)}console.log(`Preflight passed: ${checks.length}/${checks.length} checks healthy; no episode was published.`);
