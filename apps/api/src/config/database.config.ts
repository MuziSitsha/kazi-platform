import { registerAs } from '@nestjs/config';

export default registerAs('database', () => ({
  url: process.env.DATABASE_URL,
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT || '5432', 10),
  username: process.env.DB_USERNAME || 'kazi',
  password: process.env.DB_PASSWORD || 'kazi_dev',
  name: process.env.DB_NAME || 'kazi_db',
}));
