import {
  Entity, PrimaryGeneratedColumn, Column,
  CreateDateColumn, UpdateDateColumn,
  ManyToOne, JoinColumn, Index,
} from 'typeorm';
import { UserEntity } from '../../users/entities/user.entity';

export enum BookingStatus {
  PENDING = 'pending',           // Customer placed booking
  ACCEPTED = 'accepted',         // Provider accepted
  EN_ROUTE = 'en_route',         // Provider travelling to customer
  ARRIVED = 'arrived',           // Provider at customer location
  IN_PROGRESS = 'in_progress',   // Service being done
  COMPLETED = 'completed',       // Service done
  CANCELLED = 'cancelled',       // Cancelled by either party
  DISPUTED = 'disputed',         // Admin review needed
}

export enum BookingType {
  INSTANT = 'instant',
  SCHEDULED = 'scheduled',
}

export enum PaymentMethod {
  CASH = 'cash',
  CARD = 'card',
  WALLET = 'wallet',
  EFT = 'eft',
}

export enum PaymentStatus {
  PENDING = 'pending',
  PAID = 'paid',
  REFUNDED = 'refunded',
  FAILED = 'failed',
}

@Entity('bookings')
@Index(['customerId'])
@Index(['providerId'])
@Index(['status'])
@Index(['scheduledAt'])
export class BookingEntity {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  // Short human-readable ID (e.g. KZ-2024-001234)
  @Column({ unique: true })
  bookingRef: string;

  @Column()
  customerId: string;

  @ManyToOne(() => UserEntity)
  @JoinColumn({ name: 'customerId' })
  customer: UserEntity;

  @Column({ nullable: true })
  providerId: string;

  @ManyToOne(() => UserEntity, { nullable: true })
  @JoinColumn({ name: 'providerId' })
  provider: UserEntity;

  @Column()
  serviceCategoryId: string;

  @Column()
  serviceId: string;

  @Column({ type: 'enum', enum: BookingType, default: BookingType.INSTANT })
  type: BookingType;

  @Column({ type: 'enum', enum: BookingStatus, default: BookingStatus.PENDING })
  status: BookingStatus;

  // Location
  @Column('decimal', { precision: 10, scale: 8, nullable: true })
  customerLat: number;

  @Column('decimal', { precision: 11, scale: 8, nullable: true })
  customerLng: number;

  @Column({ nullable: true })
  customerAddress: string;

  // Pricing (in ZAR cents to avoid float issues)
  @Column({ default: 0 })
  quotedPriceCents: number;

  @Column({ default: 0 })
  finalPriceCents: number;

  @Column({ default: 0 })
  commissionCents: number;

  @Column({ default: 0 })
  providerEarningsCents: number;

  // Discount
  @Column({ nullable: true })
  promoCode: string;

  @Column({ default: 0 })
  discountCents: number;

  // Payment
  @Column({ type: 'enum', enum: PaymentMethod, default: PaymentMethod.CASH })
  paymentMethod: PaymentMethod;

  @Column({ type: 'enum', enum: PaymentStatus, default: PaymentStatus.PENDING })
  paymentStatus: PaymentStatus;

  @Column({ nullable: true })
  paymentGatewayRef: string;

  // Scheduling
  @Column({ nullable: true })
  scheduledAt: Date;

  // Tracking timestamps
  @Column({ nullable: true })
  acceptedAt: Date;

  @Column({ nullable: true })
  enRouteAt: Date;

  @Column({ nullable: true })
  arrivedAt: Date;

  @Column({ nullable: true })
  startedAt: Date;

  @Column({ nullable: true })
  completedAt: Date;

  @Column({ nullable: true })
  cancelledAt: Date;

  @Column({ nullable: true })
  cancelReason: string;

  @Column({ nullable: true })
  cancelledBy: string;

  // Notes
  @Column({ type: 'text', nullable: true })
  customerNotes: string;

  @Column({ type: 'text', nullable: true })
  providerNotes: string;

  // Rating
  @Column({ default: false })
  isRated: boolean;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;

  // Computed helpers
  get quotedPrice(): number { return this.quotedPriceCents / 100; }
  get finalPrice(): number { return this.finalPriceCents / 100; }
  get commission(): number { return this.commissionCents / 100; }
  get providerEarnings(): number { return this.providerEarningsCents / 100; }
}
