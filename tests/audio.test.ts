import { describe, expect, it } from "vitest";
import { mixArgs } from "@/lib/audio";

describe("podcast mix graph", () => {
  it("loops music and ends exactly with speech", () => {
    const args = mixArgs("speech.mp3", "music.mp3", "final.mp3", 603.25);
    expect(args).toContain("-stream_loop");
    expect(args).toContain("603.250");
    expect(args.join(" ")).toContain("duration=first");
    expect(args.join(" ")).toContain("afade=t=out:st=601.250:d=2");
    expect(args.join(" ")).toContain("alimiter=limit=0.95");
  });

  it("never creates a negative fade start", () => {
    expect(mixArgs("s","m","o",1).join(" ")).toContain("afade=t=out:st=0.000:d=2");
  });
});
