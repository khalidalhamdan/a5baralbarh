import postgres from "postgres"; import { env } from "@/lib/env";
let client:ReturnType<typeof postgres>|undefined;
export function db(){if(!env.DATABASE_URL)throw new Error("DATABASE_URL is missing");return client??=postgres(env.DATABASE_URL,{max:5,prepare:false})}
export async function audit(action:string,entityType:string,entityId:string,details:Record<string,unknown>={}){await db()`insert into audit_events(action,entity_type,entity_id,details) values(${action},${entityType},${entityId},${db().json(details as never)})`}
