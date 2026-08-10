import { z } from "zod";
const schema = z.object({
  DATABASE_URL: z.string().optional(),
  OPENAI_API_KEY: z.string().optional(),
  OPENAI_MODEL: z.string().default("gpt-4.1-mini"),
  ELEVENLABS_API_KEY: z.string().optional(),
  ELEVENLABS_HOST_A_VOICE_ID: z.string().optional(),
  ELEVENLABS_HOST_B_VOICE_ID: z.string().optional(),
  AZURE_SPEECH_KEY: z.string().optional(),
  AZURE_SPEECH_REGION: z.string().optional(),
  TRANSISTOR_API_KEY: z.string().optional(),
  TRANSISTOR_SHOW_ID: z.string().optional(),
  TELEGRAM_BOT_TOKEN: z.string().optional(),
  TELEGRAM_CHAT_ID: z.string().optional(),
  OWNER_EMAIL: z.string().email().optional(),
  PUBLISHING_ENABLED: z.string().default("false").transform((v) => v === "true"),
  APP_TIMEZONE: z.string().default("Asia/Riyadh"),
  WORKER_TRIGGER_TOKEN: z.string().optional(),
});

export const env = schema.parse(process.env);
