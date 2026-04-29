import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { UserEntity } from '../users/entities/user.entity';
import { WalletController } from './wallet.controller';
import { WalletTransactionEntity } from './entities/wallet-transaction.entity';
import { WalletService } from './wallet.service';

@Module({
	imports: [TypeOrmModule.forFeature([UserEntity, WalletTransactionEntity])],
	controllers: [WalletController],
	providers: [WalletService],
	exports: [WalletService],
})
export class WalletModule {}