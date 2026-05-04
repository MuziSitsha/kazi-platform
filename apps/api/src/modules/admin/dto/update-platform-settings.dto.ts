import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsBoolean, IsNumber, IsOptional, IsString, Max, Min, MaxLength } from 'class-validator';

export class UpdatePlatformSettingsDto {
  @ApiPropertyOptional({ example: 0.18 })
  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 4 })
  @Min(0)
  @Max(0.5)
  defaultCommissionRate?: number;

  @ApiPropertyOptional({ example: true })
  @IsOptional()
  @IsBoolean()
  cashPaymentsEnabled?: boolean;

  @ApiPropertyOptional({ example: true })
  @IsOptional()
  @IsBoolean()
  cardPaymentsEnabled?: boolean;

  @ApiPropertyOptional({ example: true })
  @IsOptional()
  @IsBoolean()
  walletPaymentsEnabled?: boolean;

  @ApiPropertyOptional({ example: true })
  @IsOptional()
  @IsBoolean()
  instantBookingsEnabled?: boolean;

  @ApiPropertyOptional({ example: true })
  @IsOptional()
  @IsBoolean()
  scheduledBookingsEnabled?: boolean;

  @ApiPropertyOptional({ example: 'KAZI Marketplace (Pty) Ltd' })
  @IsOptional()
  @IsString()
  @MaxLength(120)
  businessLegalName?: string;

  @ApiPropertyOptional({ example: 'FNB' })
  @IsOptional()
  @IsString()
  @MaxLength(120)
  payoutBankName?: string;

  @ApiPropertyOptional({ example: 'KAZI Marketplace' })
  @IsOptional()
  @IsString()
  @MaxLength(120)
  payoutAccountHolder?: string;

  @ApiPropertyOptional({ example: '62123456789' })
  @IsOptional()
  @IsString()
  @MaxLength(40)
  payoutAccountNumber?: string;

  @ApiPropertyOptional({ example: 'Business Cheque' })
  @IsOptional()
  @IsString()
  @MaxLength(80)
  payoutAccountType?: string;

  @ApiPropertyOptional({ example: '250655' })
  @IsOptional()
  @IsString()
  @MaxLength(20)
  payoutBranchCode?: string;

  @ApiPropertyOptional({ example: 'KAZI settlements' })
  @IsOptional()
  @IsString()
  @MaxLength(120)
  payoutReference?: string;
}