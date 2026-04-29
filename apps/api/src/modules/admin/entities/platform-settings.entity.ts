import {
  Column,
  CreateDateColumn,
  Entity,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';

@Entity('platform_settings')
export class PlatformSettingsEntity {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column('decimal', { precision: 5, scale: 4, default: 0.15 })
  defaultCommissionRate: number;

  @Column({ default: true })
  cashPaymentsEnabled: boolean;

  @Column({ default: true })
  cardPaymentsEnabled: boolean;

  @Column({ default: true })
  walletPaymentsEnabled: boolean;

  @Column({ default: true })
  instantBookingsEnabled: boolean;

  @Column({ default: true })
  scheduledBookingsEnabled: boolean;

  @Column({ nullable: true })
  updatedByUserId: string;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}