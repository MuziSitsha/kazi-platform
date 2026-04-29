import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';
import { PaymentMethod, PaymentStatus } from '../../bookings/entities/booking.entity';

@Entity('payment_transactions')
@Index(['bookingId'], { unique: true })
@Index(['customerId'])
@Index(['providerId'])
export class PaymentTransactionEntity {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  bookingId: string;

  @Column()
  customerId: string;

  @Column({ nullable: true })
  providerId: string;

  @Column({
    type: 'enum',
    enum: PaymentMethod,
  })
  paymentMethod: PaymentMethod;

  @Column({
    type: 'enum',
    enum: PaymentStatus,
    default: PaymentStatus.PENDING,
  })
  status: PaymentStatus;

  @Column()
  amountCents: number;

  @Column({ default: 0 })
  commissionCents: number;

  @Column({ default: 0 })
  providerEarningsCents: number;

  @Column({ nullable: true })
  gatewayReference: string;

  @Column({ type: 'text', nullable: true })
  note: string;

  @Column({ nullable: true })
  settledAt: Date;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}