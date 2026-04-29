import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Request,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { AuthGuard } from '@nestjs/passport';
import { SettleBookingPaymentDto } from './dto/settle-booking-payment.dto';
import { PaymentsService } from './payments.service';

@ApiTags('payments')
@ApiBearerAuth()
@UseGuards(AuthGuard('jwt'))
@Controller('payments')
export class PaymentsController {
  constructor(private readonly paymentsService: PaymentsService) {}

  @Get('mine')
  @ApiOperation({ summary: 'List payments visible to the current user' })
  listMyPayments(@Request() req) {
    return this.paymentsService.listMyPayments(req.user.id, req.user.role);
  }

  @Get('bookings/:bookingId')
  @ApiOperation({ summary: 'Get the payment transaction for a booking' })
  getBookingPayment(@Request() req, @Param('bookingId') bookingId: string) {
    return this.paymentsService.getBookingPayment(bookingId, req.user.id, req.user.role);
  }

  @Post('bookings/:bookingId/settle')
  @ApiOperation({ summary: 'Settle a booking payment and post earnings to the provider wallet' })
  settleBooking(
    @Request() req,
    @Param('bookingId') bookingId: string,
    @Body() dto: SettleBookingPaymentDto,
  ) {
    return this.paymentsService.settleBooking(bookingId, {
      actorId: req.user.id,
      actorRole: req.user.role,
      gatewayReference: dto.gatewayReference,
      note: dto.note,
    });
  }
}