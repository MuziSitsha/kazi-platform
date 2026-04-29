import {
  Entity, PrimaryGeneratedColumn, Column,
  CreateDateColumn, UpdateDateColumn, OneToMany, Index,
} from 'typeorm';
import { Exclude } from 'class-transformer';

export enum UserRole {
  CUSTOMER = 'customer',
  PROVIDER = 'provider',
  ADMIN = 'admin',
}

export enum UserStatus {
  ACTIVE = 'active',
  INACTIVE = 'inactive',
  SUSPENDED = 'suspended',
  PENDING_VERIFICATION = 'pending_verification',
}

@Entity('users')
@Index(['phone'], { unique: true })
@Index(['email'], { unique: true, where: 'email IS NOT NULL' })
export class UserEntity {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ unique: true })
  phone: string;

  @Column({ nullable: true, unique: true })
  email: string;

  @Column({ nullable: true })
  firstName: string;

  @Column({ nullable: true })
  lastName: string;

  @Column({ nullable: true })
  avatarUrl: string;

  @Column({ type: 'enum', enum: UserRole, default: UserRole.CUSTOMER })
  role: UserRole;

  @Column({ type: 'enum', enum: UserStatus, default: UserStatus.ACTIVE })
  status: UserStatus;

  @Column({ default: true })
  isActive: boolean;

  @Column({ default: false })
  isPhoneVerified: boolean;

  @Column({ default: false })
  isEmailVerified: boolean;

  // SA-specific: preferred language
  @Column({ default: 'en' })
  preferredLanguage: string;

  // Referral system
  @Column({ unique: true, nullable: true })
  referralCode: string;

  @Column({ nullable: true })
  referredByCode: string;

  // Push notifications
  @Column({ nullable: true })
  @Exclude()
  fcmToken: string;

  // Wallet balance in ZAR cents (avoid floating point issues)
  @Column({ default: 0 })
  walletBalanceCents: number;

  @Column({ nullable: true })
  lastActiveAt: Date;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;

  // Virtual getters
  get fullName(): string {
    return [this.firstName, this.lastName].filter(Boolean).join(' ');
  }

  get walletBalance(): number {
    return this.walletBalanceCents / 100;
  }
}
