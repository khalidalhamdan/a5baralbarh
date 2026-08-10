import OpenAI from "openai";
import { GeneratedEpisode, type TextGenerationProvider } from "@/lib/domain";
import { env } from "@/lib/env";

export class OpenAITextProvider implements TextGenerationProvider {
  private client=new OpenAI({apiKey:env.OPENAI_API_KEY});
  async createEpisode(input:Parameters<TextGenerationProvider["createEpisode"]>[0]) {
    if(!env.OPENAI_API_KEY) throw new Error("OPENAI_API_KEY is not configured");
    const response=await this.client.responses.create({model:env.OPENAI_MODEL,input:[{role:"system",content:`أنت رئيس تحرير سعودي دقيق. اكتب حواراً طبيعياً بلهجة نجدية عصرية ومحترمة بين مضيفين. لا تضف أي حقيقة غير موجودة في المواد. افصل الخبر عن الرأي، وانسب الادعاءات لمصادرها. كل مقطع يجب أن يحمل روابط مصادره. أضف إفصاحاً بأن الأصوات مولدة بالذكاء الاصطناعي. أعد JSON فقط.`},{role:"user",content:JSON.stringify(input)}],text:{format:{type:"json_schema",name:"episode",strict:true,schema:zodJsonSchema}}});
    return GeneratedEpisode.parse(JSON.parse(response.output_text));
  }
}
const zodJsonSchema={type:"object",additionalProperties:false,required:["title","description","summary","telegramCaption","segments","sourceUrls","estimatedSeconds","disclosure"],properties:{title:{type:"string"},description:{type:"string"},summary:{type:"string"},telegramCaption:{type:"string"},sourceUrls:{type:"array",items:{type:"string",format:"uri"},minItems:1},estimatedSeconds:{type:"number",minimum:480,maximum:720},disclosure:{type:"string"},segments:{type:"array",minItems:5,maxItems:8,items:{type:"object",additionalProperties:false,required:["id","speaker","text","storyId","sourceUrls","pronunciationNotes","estimatedSeconds"],properties:{id:{type:"string"},speaker:{enum:["host_a","host_b"]},text:{type:"string"},storyId:{type:"string"},sourceUrls:{type:"array",items:{type:"string",format:"uri"}},pronunciationNotes:{type:"array",items:{type:"string"}},estimatedSeconds:{type:"number"}}}}} as const;
