import {
  BadRequestException,
  Injectable,
  InternalServerErrorException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PutObjectCommand, S3Client } from '@aws-sdk/client-s3';

type UploadedProviderAsset = {
  key: string;
  fileUrl: string;
};

@Injectable()
export class ProviderDocumentStorageService {
  private readonly s3Client: S3Client;
  private readonly bucketName: string;
  private readonly region: string;

  constructor(private readonly configService: ConfigService) {
    this.region = this.configService.get<string>('app.awsRegion') || 'af-south-1';
    this.bucketName = this.configService.get<string>('app.awsS3BucketName') || '';

    this.s3Client = new S3Client({
      region: this.region,
      credentials: {
        accessKeyId: this.configService.get<string>('app.awsAccessKeyId') || '',
        secretAccessKey: this.configService.get<string>('app.awsSecretAccessKey') || '',
      },
    });
  }

  async upload(userId: string, documentType: string, file: Express.Multer.File): Promise<UploadedProviderAsset> {
    this.assertUploadIsConfigured();

    if (!file.buffer?.length) {
      throw new BadRequestException('Uploaded file is empty');
    }

    const sanitizedType = this.slugify(documentType);
    const sanitizedName = this.slugify(file.originalname.replace(/\.[^/.]+$/, ''));
    const extension = this.extractExtension(file.originalname);
    const key = `providers/${userId}/${sanitizedType}/${Date.now()}-${sanitizedName}${extension}`;

    try {
      await this.s3Client.send(new PutObjectCommand({
        Bucket: this.bucketName,
        Key: key,
        Body: file.buffer,
        ContentType: file.mimetype,
        Metadata: {
          userId,
          documentType: sanitizedType,
          originalName: file.originalname,
        },
      }));
    } catch (error) {
      throw new InternalServerErrorException('Failed to upload provider document to S3');
    }

    return {
      key,
      fileUrl: `https://${this.bucketName}.s3.${this.region}.amazonaws.com/${key}`,
    };
  }

  private assertUploadIsConfigured() {
    if (!this.bucketName) {
      throw new ServiceUnavailableException('AWS S3 bucket is not configured');
    }

    const accessKeyId = this.configService.get<string>('app.awsAccessKeyId');
    const secretAccessKey = this.configService.get<string>('app.awsSecretAccessKey');
    if (!accessKeyId || !secretAccessKey) {
      throw new ServiceUnavailableException('AWS S3 credentials are not configured');
    }
  }

  private extractExtension(fileName: string) {
    const match = fileName.match(/(\.[a-zA-Z0-9]+)$/);
    return match ? match[1].toLowerCase() : '';
  }

  private slugify(value: string) {
    return value
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/^-+|-+$/g, '')
      .slice(0, 80) || 'document';
  }
}