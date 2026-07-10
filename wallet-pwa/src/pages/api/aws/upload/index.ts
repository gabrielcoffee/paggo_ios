import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { HttpStatusCode } from 'axios';
import { NextApiResponse } from 'next';

import { NextApiRequestLogged } from '@paggo/middlewares/types';
import { AWSUploadDto } from '@paggo/services/dto';

const getBucketName = (bucket?: string) => {
  switch (bucket) {
    default:
      return process.env.S3_MANUAL_UPLOAD_BUCKET_NAME;
  }
};

const CDN_BASE_URL = process.env.CDN_BASE_URL;

export default async function handler(
  req: NextApiRequestLogged<AWSUploadDto>,
  res: NextApiResponse
) {
  const { bucket, file, fileType } = req.body;

  const BUCKET_NAME = getBucketName(bucket as string);

  const S3_CONFIG = {
    region: process.env.AWS_REGION || 'us-east-1',
    credentials: {
      accessKeyId: process.env.AWS_ACCESS_KEY_ID || '',
      secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY || '',
    },
  };

  const s3Client = new S3Client(S3_CONFIG);
  const normalizedFile = file
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-zA-Z0-9]/g, '_');
  const path = `${BUCKET_NAME}/${normalizedFile}`;

  try {
    const command = new PutObjectCommand({
      Bucket: BUCKET_NAME,
      Key: path,
      ContentType: fileType,
    });

    const preSignedUrl = await getSignedUrl(s3Client, command, { expiresIn: 5 * 60, signableHeaders: new Set(['content-type']) });

    res.status(HttpStatusCode.Ok).json({
      url: preSignedUrl,
      cdnUrl: `${CDN_BASE_URL}${path}`,
    });
  } catch (error: any) {
    res.status(HttpStatusCode.InternalServerError).json({ error: error.message });
  }
}
