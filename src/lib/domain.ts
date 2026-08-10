import { z } from "zod";

export const EpisodeStatus = z.enum(["collecting","researching","scripting","synthesizing","mixing","needs_review","approved","publishing","published","failed","archived"]);
export type EpisodeStatus = z.infer<typeof EpisodeStatus>;
export const transitions: Record<EpisodeStatus, EpisodeStatus[]> = {
  collecting:["researching","failed"], researching:["scripting","failed"], scripting:["synthesizing","failed"],
  synthesizing:["mixing","failed"], mixing:["needs_review","failed"], needs_review:["scripting","approved","archived"],
  approved:["publishing","archived"], publishing:["published","failed"], published:["archived"], failed:["collecting","researching","scripting","synthesizing","mixing","publishing","archived"], archived:[]
};
export function assertTransition(from: EpisodeStatus,to: EpisodeStatus){if(!transitions[from].includes(to))throw new Error(`Invalid episode transition: ${from} -> ${to}`)}

export const ScriptSegment = z.object({ id:z.string(), speaker:z.enum(["host_a","host_b"]), text:z.string().min(1), storyId:z.string(), sourceUrls:z.array(z.string().url()).min(1), pronunciationNotes:z.array(z.string()).default([]), estimatedSeconds:z.number().positive() });
export type ScriptSegment = z.infer<typeof ScriptSegment>;
export const GeneratedEpisode = z.object({
  title: z.string(),
  description: z.string(),
  summary: z.string(),
  telegramCaption: z.string(),
  segments: z.array(ScriptSegment).min(5).max(8),
  sourceUrls: z.array(z.string().url()).min(1),
  estimatedSeconds: z.number().min(480).max(720),
  disclosure: z.string()
}).refine((episode) => {
  const speakers = new Set(episode.segments.map((segment) => segment.speaker));
  return speakers.has("host_a") && speakers.has("host_b");
}, {
  path: ["segments"],
  message: "Episode must include both host_a and host_b"
});
export type GeneratedEpisode = z.infer<typeof GeneratedEpisode>;

export interface TextGenerationProvider { createEpisode(input:{ stories:Array<{id:string;title:string;content:string;sources:string[];sensitive:boolean}>; targetSeconds:number }):Promise<GeneratedEpisode> }
export interface SpeechProvider { synthesize(input:{text:string;speaker:"host_a"|"host_b";outputPath:string}):Promise<{provider:string;model:string;voiceId:string;costSar?:number}> }
export interface PodcastPublisher { publish(input:{idempotencyKey:string;title:string;description:string;audioUrl:string;publishAt?:Date}):Promise<{externalId:string;publicUrl:string;enclosureUrl:string}>; unpublish(externalId:string):Promise<void> }
export interface MessagePublisher { publish(input:{idempotencyKey:string;title:string;caption:string;url:string}):Promise<{externalId:string}> }
export interface ObjectStorageProvider { put(key:string,body:Uint8Array,contentType:string):Promise<string>; signedUrl(key:string,ttlSeconds:number):Promise<string> }
