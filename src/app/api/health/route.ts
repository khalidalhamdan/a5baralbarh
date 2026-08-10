import { NextResponse } from "next/server";
export async function GET(){return NextResponse.json({ok:true,service:"najdi-news-admin",time:new Date().toISOString(),publishingEnabled:process.env.PUBLISHING_ENABLED==="true"})}
