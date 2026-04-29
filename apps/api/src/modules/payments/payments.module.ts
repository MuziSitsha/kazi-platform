import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { BookingEntity } from '../bookings/entities/booking.entity';
import { UserEntity } from '../users/entities/user.entity';
import { WalletModule } from '../wallet/wallet.module';
import { PaymentsController } from './payments.controller';
import { PaymentTransactionEntity } from './entities/payment-transaction.entity';
import { PaymentsService } from './payments.service';

@Module({
	imports: [
		TypeOrmModule.forFeature([PaymentTransactionEntity, BookingEntity, UserEntity]),
		WalletModule,
	],
	controllers: [PaymentsController],
	providers: [PaymentsService],
	exports: [PaymentsService],
})
export class PaymentsModule {}