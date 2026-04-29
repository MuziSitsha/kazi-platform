import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ThrottlerModule } from '@nestjs/throttler';
import { BullModule } from '@nestjs/bull';
import { ScheduleModule } from '@nestjs/schedule';

import { AuthModule } from './modules/auth/auth.module';
import { UsersModule } from './modules/users/users.module';
import { ProvidersModule } from './modules/providers/providers.module';
import { BookingsModule } from './modules/bookings/bookings.module';
import { ServicesModule } from './modules/services/services.module';
import { PaymentsModule } from './modules/payments/payments.module';
import { ChatModule } from './modules/chat/chat.module';
import { NotificationsModule } from './modules/notifications/notifications.module';
import { AdminModule } from './modules/admin/admin.module';
import { WalletModule } from './modules/wallet/wallet.module';
import { ReviewsModule } from './modules/reviews/reviews.module';
import { PromosModule } from './modules/promos/promos.module';
import appConfig from './config/app.config';
import databaseConfig from './config/database.config';

@Module({
  imports: [
    // Config - loads .env
    ConfigModule.forRoot({
      isGlobal: true,
      load: [appConfig, databaseConfig],
      envFilePath: ['.env.local', '.env'],
    }),

    // PostgreSQL via TypeORM
    TypeOrmModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        type: 'postgres',
        url: config.get<string>('database.url'),
        autoLoadEntities: true,
        synchronize: config.get<string>('app.env') === 'development',
        logging: config.get<string>('app.env') === 'development',
        ssl: config.get<string>('app.env') === 'production'
          ? { rejectUnauthorized: false }
          : false,
      }),
    }),

    // Redis job queue (BullMQ) - for notifications, emails, payouts
    BullModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        redis: {
          host: config.get<string>('app.redisHost') || 'localhost',
          port: config.get<number>('app.redisPort') || 6379,
          password: config.get<string>('app.redisPassword'),
        },
      }),
    }),

    // Rate limiting - protect against abuse
    ThrottlerModule.forRoot([
      { name: 'short', ttl: 1000, limit: 10 },
      { name: 'medium', ttl: 10000, limit: 50 },
      { name: 'long', ttl: 60000, limit: 200 },
    ]),

    // Cron jobs (booking reminders, payout processing)
    ScheduleModule.forRoot(),

    // Feature modules
    AuthModule,
    UsersModule,
    ProvidersModule,
    BookingsModule,
    ServicesModule,
    PaymentsModule,
    ChatModule,
    NotificationsModule,
    AdminModule,
    WalletModule,
    ReviewsModule,
    PromosModule,
  ],
})
export class AppModule {}
