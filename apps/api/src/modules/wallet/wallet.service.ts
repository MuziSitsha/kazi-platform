import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { UserEntity } from '../users/entities/user.entity';
import {
  WalletReferenceType,
  WalletTransactionDirection,
  WalletTransactionEntity,
} from './entities/wallet-transaction.entity';

type RecordWalletTransactionInput = {
  userId: string;
  direction: WalletTransactionDirection;
  amountCents: number;
  referenceType: WalletReferenceType;
  referenceId?: string;
  bookingId?: string;
  paymentTransactionId?: string;
  description: string;
};

@Injectable()
export class WalletService {
  constructor(
    @InjectRepository(UserEntity)
    private readonly usersRepository: Repository<UserEntity>,
    @InjectRepository(WalletTransactionEntity)
    private readonly walletTransactionsRepository: Repository<WalletTransactionEntity>,
  ) {}

  async getWallet(userId: string) {
    const user = await this.usersRepository.findOne({ where: { id: userId } });
    if (!user) throw new NotFoundException('User not found');

    const transactions = await this.walletTransactionsRepository.find({
      where: { userId },
      order: { createdAt: 'DESC' },
      take: 50,
    });

    return {
      userId,
      balanceCents: user.walletBalanceCents,
      balance: user.walletBalance,
      transactions,
    };
  }

  async recordTransaction(input: RecordWalletTransactionInput) {
    const existing = input.referenceId
      ? await this.walletTransactionsRepository.findOne({
        where: {
          userId: input.userId,
          referenceType: input.referenceType,
          referenceId: input.referenceId,
        },
      })
      : null;
    if (existing) return existing;

    const user = await this.usersRepository.findOne({ where: { id: input.userId } });
    if (!user) throw new NotFoundException('User not found');
    if (input.amountCents <= 0) {
      throw new BadRequestException('Wallet transaction amount must be greater than zero');
    }

    const delta = input.direction === WalletTransactionDirection.CREDIT
      ? input.amountCents
      : -input.amountCents;
    const balanceBeforeCents = user.walletBalanceCents;
    const balanceAfterCents = balanceBeforeCents + delta;

    if (balanceAfterCents < 0) {
      throw new BadRequestException('Insufficient wallet balance');
    }

    user.walletBalanceCents = balanceAfterCents;
    await this.usersRepository.save(user);

    const transaction = this.walletTransactionsRepository.create({
      ...input,
      balanceBeforeCents,
      balanceAfterCents,
    });

    return this.walletTransactionsRepository.save(transaction);
  }
}