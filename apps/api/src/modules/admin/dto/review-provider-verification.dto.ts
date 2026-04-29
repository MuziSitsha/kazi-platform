import { ApiProperty } from '@nestjs/swagger';
import { IsArray, IsEnum, IsOptional, IsString, MaxLength } from 'class-validator';
import { ProviderVerificationStatus } from '../../providers/entities/provider-profile.entity';

export class ReviewProviderVerificationDto {
  @ApiProperty({ enum: ProviderVerificationStatus })
  @IsEnum(ProviderVerificationStatus)
  status: ProviderVerificationStatus;

  @ApiProperty({ required: false, example: 'ID and address verified successfully.' })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  note?: string;

  @ApiProperty({ required: false, type: [String] })
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  documentIds?: string[];
}