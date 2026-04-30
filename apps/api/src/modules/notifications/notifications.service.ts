import { ForbiddenException, Injectable, Logger, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { InjectRepository } from '@nestjs/typeorm';
import { App, cert, getApp, getApps, initializeApp } from 'firebase-admin/app';
import { getMessaging } from 'firebase-admin/messaging';
import { Repository } from 'typeorm';
import { NotificationEntity } from './entities/notification.entity';
import { UserEntity } from '../users/entities/user.entity';

type CreateNotificationInput = {
  userId: string;
  title: string;
  body: string;
  type: string;
  payload?: Record<string, unknown>;
};

@Injectable()
export class NotificationsService {
  private readonly logger = new Logger(NotificationsService.name);
  private readonly firebaseApp: App | null;

  constructor(
    @InjectRepository(NotificationEntity)
    private readonly notificationsRepository: Repository<NotificationEntity>,
    @InjectRepository(UserEntity)
    private readonly usersRepository: Repository<UserEntity>,
    private readonly configService: ConfigService,
  ) {
    this.firebaseApp = this.createFirebaseApp();
  }

  async listMine(userId: string) {
    const items = await this.notificationsRepository.find({
      where: { userId },
      order: { createdAt: 'DESC' },
      take: 50,
    });

    return {
      unreadCount: items.filter((item) => !item.isRead).length,
      items,
    };
  }

  async markRead(notificationId: string, userId: string) {
    const notification = await this.notificationsRepository.findOne({ where: { id: notificationId } });
    if (!notification) throw new NotFoundException('Notification not found');
    if (notification.userId !== userId) {
      throw new ForbiddenException('You cannot update another user\'s notification');
    }

    if (!notification.isRead) {
      notification.isRead = true;
      notification.readAt = new Date();
      await this.notificationsRepository.save(notification);
    }

    return notification;
  }

  async markAllRead(userId: string) {
    const unread = await this.notificationsRepository.find({ where: { userId, isRead: false } });
    if (unread.length === 0) {
      return { updatedCount: 0 };
    }

    const now = new Date();
    unread.forEach((item) => {
      item.isRead = true;
      item.readAt = now;
    });
    await this.notificationsRepository.save(unread);
    return { updatedCount: unread.length };
  }

  async createNotification(input: CreateNotificationInput) {
    const notification = this.notificationsRepository.create({
      userId: input.userId,
      title: input.title,
      body: input.body,
      type: input.type,
      payload: input.payload ?? null,
    });
    const savedNotification = await this.notificationsRepository.save(notification);

    await this.sendPushNotification(savedNotification);

    return savedNotification;
  }

  private createFirebaseApp(): App | null {
    const projectId = this.configService.get<string>('app.firebaseProjectId');
    const clientEmail = this.configService.get<string>('app.firebaseClientEmail');
    const privateKey = this.configService.get<string>('app.firebasePrivateKey');

    if (!projectId || !clientEmail || !privateKey) {
      return null;
    }

    if (getApps().length > 0) {
      return getApp();
    }

    return initializeApp({
      credential: cert({
        projectId,
        clientEmail,
        privateKey,
      }),
      projectId,
    });
  }

  private async sendPushNotification(notification: NotificationEntity) {
    if (!this.firebaseApp) {
      return;
    }

    const user = await this.usersRepository.findOne({
      where: { id: notification.userId },
      select: ['id', 'fcmToken'],
    });

    if (!user?.fcmToken) {
      return;
    }

    try {
      await getMessaging(this.firebaseApp).send({
        token: user.fcmToken,
        notification: {
          title: notification.title,
          body: notification.body,
        },
        data: {
          notificationId: notification.id,
          type: notification.type,
          ...(notification.payload
            ? Object.fromEntries(
                Object.entries(notification.payload).map(([key, value]) => [key, String(value)]),
              )
            : {}),
        },
      });
    } catch (error) {
      this.logger.warn(
        `Failed to deliver push notification ${notification.id} to user ${notification.userId}: ${error instanceof Error ? error.message : 'unknown error'}`,
      );
    }
  }
}