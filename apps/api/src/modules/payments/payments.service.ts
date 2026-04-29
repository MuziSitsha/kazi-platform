import {
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import {
  BookingEntity,
  BookingStatus,
  PaymentMethod,
  PaymentStatus,
} from '../bookings/entities/booking.entity';
import { UserRole } from '../users/entities/user.entity';
import {
  WalletReferenceType,
  WalletTransactionDirection,
} from '../wallet/entities/wallet-transaction.entity';
import { WalletService } from '../wallet/wallet.service';
import { PaymentTransactionEntity } from './entities/payment-transaction.entity';

type SettlementActor = {
  actorId: string;
  actorRole: UserRole;
  gatewayReference?: string;
  note?: string;
};

@Injectable()
export class PaymentsService {
  constructor(
    @InjectRepository(PaymentTransactionEntity)
    private readonly paymentsRepository: Repository<PaymentTransactionEntity>,
    @InjectRepository(BookingEntity)
    private readonly bookingsRepository: Repository<BookingEntity>,
    private readonly walletService: WalletService,
  ) {}

  async listMyPayments(userId: string, role: UserRole) {
    const where = role === UserRole.PROVIDER ? { providerId: userId } : { customerId: userId };
    return this.paymentsRepository.find({
      where,
      order: { createdAt: 'DESC' },
    });
  }

  async getBookingPayment(bookingId: string, actorId: string, actorRole: UserRole) {
    const booking = await this.bookingsRepository.findOne({ where: { id: bookingId } });
    if (!booking) throw new NotFoundException('Booking not found');
    this.assertActorCanAccessBooking(booking, actorId, actorRole);

    return this.paymentsRepository.findOne({ where: { bookingId } });
  }

  async settleBooking(bookingId: string, actor: SettlementActor) {
    const booking = await this.bookingsRepository.findOne({ where: { id: bookingId } });
    if (!booking) throw new NotFoundException('Booking not found');
    this.assertActorCanAccessBooking(booking, actor.actorId, actor.actorRole);
    return this.settleBookingCompletion(booking, actor);
  }

  async settleBookingCompletion(booking: BookingEntity, actor: SettlementActor) {
    if (booking.status === BookingStatus.CANCELLED) {
      throw new ForbiddenException('Cancelled bookings cannot be settled');
    }

    let payment = await this.paymentsRepository.findOne({ where: { bookingId: booking.id } });
    if (payment?.status === PaymentStatus.PAID) {
      return payment;
    }

    if (!payment) {
      payment = this.paymentsRepository.create({
        bookingId: booking.id,
        customerId: booking.customerId,
        providerId: booking.providerId,
        paymentMethod: booking.paymentMethod,
        amountCents: booking.finalPriceCents || booking.quotedPriceCents,
        commissionCents: booking.commissionCents,
        providerEarningsCents: booking.providerEarningsCents,
      });
      payment = await this.paymentsRepository.save(payment);
    }

    if (booking.paymentMethod === PaymentMethod.WALLET) {
      await this.walletService.recordTransaction({
        userId: booking.customerId,
        direction: WalletTransactionDirection.DEBIT,
        amountCents: payment.amountCents,
        referenceType: WalletReferenceType.BOOKING_PAYMENT,
        referenceId: booking.id,
        bookingId: booking.id,
        paymentTransactionId: payment.id,
        description: `Wallet payment for booking ${booking.bookingRef}`,
      });
    }

    if (booking.providerId && booking.providerEarningsCents > 0) {
      await this.walletService.recordTransaction({
        userId: booking.providerId,
        direction: WalletTransactionDirection.CREDIT,
        amountCents: booking.providerEarningsCents,
        referenceType: WalletReferenceType.PROVIDER_EARNING,
        referenceId: booking.id,
        bookingId: booking.id,
        paymentTransactionId: payment.id,
        description: `Provider earnings for booking ${booking.bookingRef}`,
      });
    }

    payment.status = PaymentStatus.PAID;
    payment.gatewayReference = actor.gatewayReference;
    payment.note = actor.note;
    payment.providerId = booking.providerId;
    payment.settledAt = new Date();

    booking.paymentStatus = PaymentStatus.PAID;
    await this.bookingsRepository.save(booking);
    return this.paymentsRepository.save(payment);
  }

  private assertActorCanAccessBooking(
    booking: BookingEntity,
    actorId: string,
    actorRole: UserRole,
  ) {
    if (actorRole === UserRole.ADMIN) return;
    if (booking.customerId === actorId || booking.providerId === actorId) return;
    throw new ForbiddenException('You do not have access to this booking payment');
  }
}