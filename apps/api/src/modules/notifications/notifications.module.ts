import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { NotificationsController } from './notifications.controller';
import { NotificationEntity } from './entities/notification.entity';
import { UserEntity } from '../users/entities/user.entity';
import { NotificationsService } from './notifications.service';

@Module({
	imports: [TypeOrmModule.forFeature([NotificationEntity, UserEntity])],
	controllers: [NotificationsController],
	providers: [NotificationsService],
	exports: [NotificationsService],
})
export class NotificationsModule {}