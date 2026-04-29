import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsString, MaxLength } from 'class-validator';

export class SettleBookingPaymentDto {
  @ApiPropertyOptional({ example: 'PEACH-TEST-12345' })
  @IsOptional()
  @IsString()
  @MaxLength(120)
  gatewayReference?: string;

  @ApiPropertyOptional({ example: 'Manual settlement after successful EFT confirmation.' })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  note?: string;
}