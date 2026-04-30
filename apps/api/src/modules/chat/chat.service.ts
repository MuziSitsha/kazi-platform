import {
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import twilio, { twiml } from 'twilio';
import { BookingEntity } from '../bookings/entities/booking.entity';
import { NotificationsService } from '../notifications/notifications.service';
import { UserEntity } from '../users/entities/user.entity';
import { ChatMessageEntity, ChatMessageType } from './entities/chat-message.entity';

@Injectable()
export class ChatService {
  private readonly logger = new Logger(ChatService.name);

  constructor(
    @InjectRepository(ChatMessageEntity)
    private readonly chatMessagesRepository: Repository<ChatMessageEntity>,
    @InjectRepository(BookingEntity)
    private readonly bookingsRepository: Repository<BookingEntity>,
    @InjectRepository(UserEntity)
    private readonly usersRepository: Repository<UserEntity>,
    private readonly notificationsService: NotificationsService,
    private readonly configService: ConfigService,
  ) {}

  async getBookingThread(bookingId: string, actorId: string) {
    const { booking, participant } = await this.assertThreadAccess(bookingId, actorId);
    const messages = await this.chatMessagesRepository.find({
      where: { bookingId },
      order: { createdAt: 'ASC' },
    });

    return {
      bookingId: booking.id,
      bookingRef: booking.bookingRef,
      participant: {
        id: participant.id,
        displayName: participant.fullName || participant.phone,
        phone: participant.phone,
      },
      messages,
    };
  }

  async sendMessage(bookingId: string, actorId: string, message: string) {
    const { booking, participant } = await this.assertThreadAccess(bookingId, actorId);
    const chatMessage = await this.chatMessagesRepository.save(
      this.chatMessagesRepository.create({
        bookingId,
        senderId: actorId,
        recipientId: participant.id,
        messageType: ChatMessageType.TEXT,
        message,
      }),
    );

    await this.notificationsService.createNotification({
      userId: participant.id,
      title: 'New booking message',
      body: message,
      type: 'chat_message',
      payload: { bookingId: booking.id, bookingRef: booking.bookingRef, chatMessageId: chatMessage.id },
    });

    return chatMessage;
  }

  async startCall(bookingId: string, actorId: string) {
    const { booking, participant, actor } = await this.assertThreadAccess(bookingId, actorId);
    let callLog = await this.chatMessagesRepository.save(
      this.chatMessagesRepository.create({
        bookingId,
        senderId: actorId,
        recipientId: participant.id,
        messageType: ChatMessageType.CALL_LOG,
        message: 'Call initiated from app',
        callStatus: 'initiated',
      }),
    );

    let callMode: 'twilio_bridge' | 'phone_fallback' = 'phone_fallback';
    let callStatus: 'bridged' | 'fallback_ready' | 'twilio_failed' = 'fallback_ready';
    let statusMessage = 'Twilio voice is not configured, so the app will fall back to the device dialer.';

    try {
      const bridgeCall = await this.tryStartTwilioBridge(actor.phone, participant.phone, booking.id);
      if (bridgeCall) {
        callMode = 'twilio_bridge';
        callStatus = 'bridged';
        statusMessage = 'Twilio is calling both participants now.';
        callLog = await this.chatMessagesRepository.save({
          ...callLog,
          message: `Twilio bridge call started for booking ${booking.bookingRef}`,
          callStatus: 'bridged',
        });
      }
    } catch (error) {
      callStatus = 'twilio_failed';
      callLog = await this.chatMessagesRepository.save({
        ...callLog,
        message: 'Twilio bridge attempt failed. Fallback to direct dial is available.',
        callStatus: 'twilio_failed',
      });
      statusMessage = 'Twilio could not connect the call, so the app will fall back to the device dialer.';
      this.logger.warn(
        `Failed to start Twilio bridge call for booking ${booking.id}: ${error instanceof Error ? error.message : 'unknown error'}`,
      );
    }

    await this.notificationsService.createNotification({
      userId: participant.id,
      title: 'Incoming call attempt',
      body: callMode === 'twilio_bridge'
        ? `Twilio is connecting a call for booking ${booking.bookingRef}.`
        : `A call was started for booking ${booking.bookingRef}.`,
      type: 'call_started',
      payload: {
        bookingId: booking.id,
        bookingRef: booking.bookingRef,
        chatMessageId: callLog.id,
        callMode,
        callStatus,
      },
    });

    return {
      bookingId: booking.id,
      bookingRef: booking.bookingRef,
      participantName: participant.fullName || participant.phone,
      participantPhone: participant.phone,
      callLogId: callLog.id,
      callMode,
      callProvider: callMode === 'twilio_bridge' ? 'twilio' : 'device_dialer',
      callStatus,
      statusMessage,
      startedAt: callLog.createdAt?.toISOString() ?? new Date().toISOString(),
    };
  }

  private async tryStartTwilioBridge(callerPhone: string, participantPhone: string, bookingId: string) {
    const accountSid = this.configService.get<string>('app.twilioAccountSid');
    const authToken = this.configService.get<string>('app.twilioAuthToken');
    const twilioPhoneNumber = this.configService.get<string>('app.twilioPhoneNumber');

    if (!accountSid || !authToken || !twilioPhoneNumber) {
      return null;
    }

    const client = twilio(accountSid, authToken);
    const voiceResponse = new twiml.VoiceResponse();
    voiceResponse.say('Kazi is connecting your booking call.');
    voiceResponse.dial().conference(`kazi-booking-${bookingId}`);

    const conferenceTwiML = voiceResponse.toString();

    const [callerLeg, participantLeg] = await Promise.all([
      client.calls.create({
        to: callerPhone,
        from: twilioPhoneNumber,
        twiml: conferenceTwiML,
      }),
      client.calls.create({
        to: participantPhone,
        from: twilioPhoneNumber,
        twiml: conferenceTwiML,
      }),
    ]);

    return {
      callerSid: callerLeg.sid,
      participantSid: participantLeg.sid,
    };
  }

  private async assertThreadAccess(bookingId: string, actorId: string) {
    const booking = await this.bookingsRepository.findOne({ where: { id: bookingId } });
    if (!booking) throw new NotFoundException('Booking not found');

    const isCustomer = booking.customerId === actorId;
    const isProvider = booking.providerId === actorId;
    if (!isCustomer && !isProvider) {
      throw new ForbiddenException('You do not have access to this booking thread');
    }

    const participantId = isCustomer ? booking.providerId : booking.customerId;
    if (!participantId) {
      throw new ForbiddenException('Chat and call become available after provider assignment');
    }

    const actor = await this.usersRepository.findOne({ where: { id: actorId } });
    if (!actor) {
      throw new NotFoundException('Current user not found');
    }

    const participant = await this.usersRepository.findOne({ where: { id: participantId } });
    if (!participant) {
      throw new NotFoundException('Booking participant not found');
    }

    return { booking, participant, actor };
  }
}