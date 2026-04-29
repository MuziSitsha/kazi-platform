import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { IsNull, Repository } from 'typeorm';
import { AdminService } from '../admin/admin.service';
import { PaymentsService } from '../payments/payments.service';
import { UserEntity, UserRole } from '../users/entities/user.entity';
import { CreateBookingDto } from './dto/create-booking.dto';
import { BookingEntity, BookingStatus, PaymentStatus } from './entities/booking.entity';

@Injectable()
export class BookingsService {
  constructor(
    @InjectRepository(BookingEntity)
    private readonly bookingsRepository: Repository<BookingEntity>,
    @InjectRepository(UserEntity)
    private readonly usersRepository: Repository<UserEntity>,
    private readonly adminService: AdminService,
    private readonly paymentsService: PaymentsService,
  ) {}

  async createBooking(customerId: string, dto: CreateBookingDto) {
    const commissionRate = await this.adminService.getEffectiveCommissionRate();

    const booking = this.bookingsRepository.create({
      ...dto,
      customerId,
      bookingRef: this.generateBookingRef(),
      finalPriceCents: dto.quotedPriceCents,
      commissionCents: Math.round(dto.quotedPriceCents * commissionRate),
      providerEarningsCents: dto.quotedPriceCents - Math.round(dto.quotedPriceCents * commissionRate),
      scheduledAt: dto.scheduledAt ? new Date(dto.scheduledAt) : null,
    });

    return this.bookingsRepository.save(booking);
  }

  async listMyBookings(userId: string, role: UserRole) {
    if (role === UserRole.PROVIDER) {
      return this.bookingsRepository.find({
        where: { providerId: userId },
        order: { createdAt: 'DESC' },
      });
    }

    return this.bookingsRepository.find({
      where: { customerId: userId },
      order: { createdAt: 'DESC' },
    });
  }

  async listAvailableForProviders() {
    return this.bookingsRepository.find({
      where: { status: BookingStatus.PENDING, providerId: IsNull() },
      order: { createdAt: 'ASC' },
    });
  }

  async acceptBooking(bookingId: string, providerId: string) {
    const provider = await this.usersRepository.findOne({ where: { id: providerId } });
    if (!provider || provider.role !== UserRole.PROVIDER) {
      throw new ForbiddenException('Only providers can accept bookings');
    }

    const booking = await this.bookingsRepository.findOne({ where: { id: bookingId } });
    if (!booking) throw new NotFoundException('Booking not found');
    if (booking.status !== BookingStatus.PENDING || booking.providerId) {
      throw new ForbiddenException('Booking is no longer available');
    }

    booking.providerId = providerId;
    booking.status = BookingStatus.ACCEPTED;
    booking.acceptedAt = new Date();
    return this.bookingsRepository.save(booking);
  }

  async updateStatus(bookingId: string, providerId: string, status: BookingStatus) {
    const booking = await this.bookingsRepository.findOne({ where: { id: bookingId } });
    if (!booking) throw new NotFoundException('Booking not found');
    if (booking.providerId !== providerId) {
      throw new ForbiddenException('Only the assigned provider can update this booking');
    }

    if (booking.status === BookingStatus.CANCELLED) {
      throw new BadRequestException('Cancelled bookings cannot be updated');
    }

    booking.status = status;
    const now = new Date();

    switch (status) {
      case BookingStatus.EN_ROUTE:
        booking.enRouteAt = now;
        break;
      case BookingStatus.ARRIVED:
        booking.arrivedAt = now;
        break;
      case BookingStatus.IN_PROGRESS:
        booking.startedAt = now;
        break;
      case BookingStatus.COMPLETED:
        booking.completedAt = now;
        await this.paymentsService.settleBookingCompletion(booking, {
          actorId: providerId,
          actorRole: UserRole.PROVIDER,
        });
        booking.paymentStatus = PaymentStatus.PAID;
        break;
      default:
        break;
    }

    return this.bookingsRepository.save(booking);
  }

  async cancelBooking(bookingId: string, actorId: string, reason: string) {
    const booking = await this.bookingsRepository.findOne({ where: { id: bookingId } });
    if (!booking) throw new NotFoundException('Booking not found');

    const canCancel = booking.customerId === actorId || booking.providerId === actorId;
    if (!canCancel) {
      throw new ForbiddenException('Only the customer or assigned provider can cancel');
    }

    if ([BookingStatus.COMPLETED, BookingStatus.CANCELLED].includes(booking.status)) {
      throw new ForbiddenException('This booking can no longer be cancelled');
    }

    booking.status = BookingStatus.CANCELLED;
    booking.cancelledAt = new Date();
    booking.cancelReason = reason;
    booking.cancelledBy = actorId;
    return this.bookingsRepository.save(booking);
  }

  private generateBookingRef() {
    const suffix = Math.random().toString(36).slice(2, 6).toUpperCase();
    return `KZ-${Date.now()}-${suffix}`;
  }
}