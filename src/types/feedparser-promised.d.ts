declare module "feedparser-promised" {
  const parser: { parse(url: string): Promise<Array<Record<string, unknown>>> };
  export default parser;
}
