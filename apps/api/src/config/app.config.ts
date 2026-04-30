import { registerAs } from '@nestjs/config';

export default registerAs('app', () => ({
  env: process.env.NODE_ENV || 'development',
  port: parseInt(process.env.PORT || '3001', 10),
  publicApiUrl: process.env.PUBLIC_API_URL || 'http://localhost:3001',
  jwtSecret: process.env.JWT_SECRET || 'kazi-secret-change-in-production',
  jwtExpiresIn: process.env.JWT_EXPIRES_IN || '7d',
  jwtRefreshExpiresIn: process.env.JWT_REFRESH_EXPIRES_IN || '30d',
  redisHost: process.env.REDIS_HOST || 'localhost',
  redisPort: parseInt(process.env.REDIS_PORT || '6379', 10),
  redisPassword: process.env.REDIS_PASSWORD,
  // Clickatell SMS (SA-based)
  clickatellApiKey: process.env.CLICKATELL_API_KEY,
  // Firebase Admin SDK
  firebaseProjectId: process.env.FIREBASE_PROJECT_ID,
  firebaseClientEmail: process.env.FIREBASE_CLIENT_EMAIL,
  firebasePrivateKey: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
  // Google Maps
  googleMapsApiKey: process.env.GOOGLE_MAPS_API_KEY,
  // Peach Payments (SA)
  peachPaymentsEntityId: process.env.PEACH_PAYMENTS_ENTITY_ID,
  peachPaymentsSecret: process.env.PEACH_PAYMENTS_SECRET,
  peachPaymentsMode: process.env.PEACH_PAYMENTS_MODE || 'test',
  // Twilio (in-app calling)
  twilioAccountSid: process.env.TWILIO_ACCOUNT_SID,
  twilioAuthToken: process.env.TWILIO_AUTH_TOKEN,
  twilioPhoneNumber: process.env.TWILIO_PHONE_NUMBER,
  // AWS S3 (document and media storage)
  awsRegion: process.env.AWS_REGION || 'af-south-1',
  awsAccessKeyId: process.env.AWS_ACCESS_KEY_ID,
  awsSecretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
  awsS3BucketName: process.env.AWS_S3_BUCKET_NAME || 'kazi-uploads',
  // Commission defaults
  defaultCommissionRate: parseFloat(process.env.DEFAULT_COMMISSION_RATE || '0.15'),
  allowedOrigins: process.env.ALLOWED_ORIGINS || 'http://localhost:3000',
}));
