import { ApiProperty } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsInt,
  IsOptional,
  IsString,
  IsUrl,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';

class ProviderDocumentInputDto {
  @ApiProperty({ example: 'national_id' })
  @IsString()
  @MaxLength(80)
  documentType: string;

  @ApiProperty({ example: 'id-front.jpg' })
  @IsString()
  @MaxLength(180)
  fileName: string;

  @ApiProperty({ example: 'https://s3.af-south-1.amazonaws.com/kazi-uploads/id-front.jpg', required: false })
  @IsOptional()
  @IsUrl()
  fileUrl?: string;

  @ApiProperty({ example: 'image/jpeg', required: false })
  @IsOptional()
  @IsString()
  @MaxLength(120)
  mimeType?: string;

  @ApiProperty({ example: 183220, required: false })
  @IsOptional()
  @IsInt()
  @Min(0)
  sizeBytes?: number;
}

export class SubmitProviderDocumentsDto {
  @ApiProperty({ type: [ProviderDocumentInputDto] })
  @IsArray()
  @ArrayMaxSize(10)
  @ValidateNested({ each: true })
  @Type(() => ProviderDocumentInputDto)
  documents: ProviderDocumentInputDto[];
}