import { GetObjectCommand, HeadBucketCommand, PutObjectCommand, S3Client } from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";
import type { ObjectStorageProvider } from "@/lib/domain";

function connection() {
  const { R2_ENDPOINT: endpoint, R2_ACCESS_KEY_ID: accessKeyId, R2_SECRET_ACCESS_KEY: secretAccessKey, R2_BUCKET: bucket } = process.env;
  if (!endpoint || !accessKeyId || !secretAccessKey || !bucket) throw new Error("R2 storage is not configured");
  return { bucket, client: new S3Client({ region: "auto", endpoint, credentials: { accessKeyId, secretAccessKey } }) };
}

export class R2Storage implements ObjectStorageProvider {
  async healthcheck(){const{client,bucket}=connection();await client.send(new HeadBucketCommand({Bucket:bucket}));return true}
  async put(key: string, body: Uint8Array, contentType: string) {
    const { client, bucket } = connection();
    await client.send(new PutObjectCommand({ Bucket: bucket, Key: key, Body: body, ContentType: contentType }));
    return key;
  }
  async signedUrl(key: string, ttlSeconds: number) {
    const { client, bucket } = connection();
    return getSignedUrl(client, new GetObjectCommand({ Bucket: bucket, Key: key }), { expiresIn: ttlSeconds });
  }
}
