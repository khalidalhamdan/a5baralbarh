import {describe,expect,it} from "vitest"; import {canonicalUrl} from "@/lib/rss";
describe("canonicalUrl",()=>{it("removes tracking and fragments",()=>expect(canonicalUrl("https://example.com/a?utm_source=x&id=2#top")).toBe("https://example.com/a?id=2"));it("rejects invalid links",()=>expect(canonicalUrl("not a url")).toBe(""))});
