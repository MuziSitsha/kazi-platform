import { ApiProperty } from '@nestjs/swagger';
import { IsString, MaxLength } from 'class-validator';

export class UploadProviderDocumentDto {
  @ApiProperty({ example: 'proof_of_address' })
  @IsString()
  @MaxLength(80)
  documentType: string;
}