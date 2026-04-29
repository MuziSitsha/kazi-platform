import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';
import { UserEntity } from '../../users/entities/user.entity';

export enum ProviderDocumentStatus {
  SUBMITTED = 'submitted',
  APPROVED = 'approved',
  REJECTED = 'rejected',
}

@Entity('provider_documents')
@Index(['userId'])
@Index(['status'])
export class ProviderDocumentEntity {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  userId: string;

  @ManyToOne(() => UserEntity)
  @JoinColumn({ name: 'userId' })
  user: UserEntity;

  @Column()
  documentType: string;

  @Column()
  fileName: string;

  @Column({ nullable: true })
  fileUrl: string;

  @Column({ nullable: true })
  mimeType: string;

  @Column({ nullable: true })
  sizeBytes: number;

  @Column({
    type: 'enum',
    enum: ProviderDocumentStatus,
    default: ProviderDocumentStatus.SUBMITTED,
  })
  status: ProviderDocumentStatus;

  @Column({ nullable: true })
  reviewedByUserId: string;

  @Column({ type: 'text', nullable: true })
  reviewNote: string;

  @Column({ nullable: true })
  reviewedAt: Date;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}