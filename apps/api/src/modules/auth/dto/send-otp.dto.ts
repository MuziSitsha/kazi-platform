import { IsString, IsMobilePhone, Length } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class SendOtpDto {
  @ApiProperty({ example: '0821234567', description: 'SA mobile number' })
  @IsString()
  @IsMobilePhone('en-ZA')
  phone: string;
}
