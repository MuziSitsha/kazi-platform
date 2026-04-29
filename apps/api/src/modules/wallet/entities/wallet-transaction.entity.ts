import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { UserEntity } from '../../users/entities/user.entity';

export enum WalletTransactionDirection {
  CREDIT = 'credit',
  DEBIT = 'debit',
}

export enum WalletReferenceType {
  BOOKING_PAYMENT = 'booking_payment',
  PROVIDER_EARNING = 'provider_earning',
  REFUND = 'refund',
  MANUAL_ADJUSTMENT = 'manual_adjustment',
}

@Entity('wallet_transactions')
@Index(['userId', 'referenceType', 'referenceId'], { unique: true })
export class WalletTransactionEntity {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  userId: string;

  @ManyToOne(() => UserEntity)
  @JoinColumn({ name: 'userId' })
  user: UserEntity;

  @Column({
    type: 'enum',
    enum: WalletTransactionDirection,
  })
  direction: WalletTransactionDirection;

  @Column({
    type: 'enum',
    enum: WalletReferenceType,
  })
  referenceType: WalletReferenceType;

  @Column({ nullable: true })
  referenceId: string;

  @Column({ nullable: true })
  bookingId: string;

  @Column({ nullable: true })
  paymentTransactionId: string;

  @Column()
  amountCents: number;

  @Column()
  balanceBeforeCents: number;

  @Column()
  balanceAfterCents: number;

  @Column({ type: 'text' })
  description: string;

  @CreateDateColumn()
  createdAt: Date;
}