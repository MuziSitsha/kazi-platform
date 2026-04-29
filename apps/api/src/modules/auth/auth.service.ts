import {
  Injectable,
  BadRequestException,
  UnauthorizedException,
  Logger,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { ConfigService } from '@nestjs/config';
import * as bcrypt from 'bcrypt';
import axios from 'axios';
import { OtpEntity } from './entities/otp.entity';
import { UsersService } from '../users/users.service';
import { UserRole } from '../users/entities/user.entity';

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);
  private readonly OTP_EXPIRY_MINUTES = 5;
  private readonly MAX_OTP_ATTEMPTS = 3;

  constructor(
    @InjectRepository(OtpEntity)
    private otpRepository: Repository<OtpEntity>,
    private usersService: UsersService,
    private jwtService: JwtService,
    private configService: ConfigService,
  ) {}

  // Step 1: Send OTP to SA mobile number
  async sendOtp(phone: string): Promise<{ message: string; expiresIn: number }> {
    const normalizedPhone = this.normalizePhone(phone);

    // Generate 6-digit OTP
    const otpCode = Math.floor(100000 + Math.random() * 900000).toString();
    const hashedOtp = await bcrypt.hash(otpCode, 10);
    const expiresAt = new Date(Date.now() + this.OTP_EXPIRY_MINUTES * 60 * 1000);

    // Invalidate any existing OTPs for this number
    await this.otpRepository.update(
      { phone: normalizedPhone, used: false },
      { used: true },
    );

    // Save new OTP
    await this.otpRepository.save({
      phone: normalizedPhone,
      hashedCode: hashedOtp,
      expiresAt,
      attempts: 0,
    });

    // Send via Clickatell (production) or log (development)
    if (this.configService.get<string>('app.env') === 'production') {
      await this.sendSmsClickatell(normalizedPhone, otpCode);
    } else {
      this.logger.debug(`[DEV] OTP for ${normalizedPhone}: ${otpCode}`);
    }

    return {
      message: 'OTP sent successfully',
      expiresIn: this.OTP_EXPIRY_MINUTES * 60,
    };
  }

  // Step 2: Verify OTP and return JWT tokens
  async verifyOtp(
    phone: string,
    code: string,
    role: UserRole = UserRole.CUSTOMER,
  ): Promise<{ accessToken: string; refreshToken: string; isNewUser: boolean; user: any }> {
    const normalizedPhone = this.normalizePhone(phone);

    const otp = await this.otpRepository.findOne({
      where: { phone: normalizedPhone, used: false },
      order: { createdAt: 'DESC' },
    });

    if (!otp) throw new UnauthorizedException('No active OTP found for this number');
    if (new Date() > otp.expiresAt) throw new UnauthorizedException('OTP has expired');
    if (otp.attempts >= this.MAX_OTP_ATTEMPTS) {
      throw new UnauthorizedException('Too many failed attempts. Request a new OTP.');
    }

    const isValid = await bcrypt.compare(code, otp.hashedCode);
    if (!isValid) {
      await this.otpRepository.increment({ id: otp.id }, 'attempts', 1);
      throw new UnauthorizedException('Invalid OTP code');
    }

    // Mark OTP as used
    await this.otpRepository.update({ id: otp.id }, { used: true });

    // Get or create user
    let user = await this.usersService.findByPhone(normalizedPhone);
    let isNewUser = false;

    if (!user) {
      user = await this.usersService.createFromPhone(normalizedPhone, role);
      isNewUser = true;
    }

    const tokens = await this.generateTokens(user.id, user.phone, user.role);
    return { ...tokens, isNewUser, user };
  }

  async refreshTokens(userId: string, refreshToken: string) {
    const user = await this.usersService.findById(userId);
    if (!user) throw new UnauthorizedException();
    return this.generateTokens(user.id, user.phone, user.role);
  }

  private async generateTokens(userId: string, phone: string, role: string) {
    const payload = { sub: userId, phone, role };
    const [accessToken, refreshToken] = await Promise.all([
      this.jwtService.signAsync(payload),
      this.jwtService.signAsync(payload, {
        expiresIn: this.configService.get<string>('app.jwtRefreshExpiresIn'),
      }),
    ]);
    return { accessToken, refreshToken };
  }

  // Normalize SA phone numbers to +27 format
  private normalizePhone(phone: string): string {
    const cleaned = phone.replace(/\s+/g, '').replace(/-/g, '');
    if (cleaned.startsWith('0')) return `+27${cleaned.slice(1)}`;
    if (cleaned.startsWith('27')) return `+${cleaned}`;
    if (cleaned.startsWith('+27')) return cleaned;
    throw new BadRequestException('Invalid South African phone number');
  }

  private async sendSmsClickatell(phone: string, otp: string): Promise<void> {
    const apiKey = this.configService.get<string>('app.clickatellApiKey');
    try {
      await axios.post(
        'https://platform.clickatell.com/messages/http/send',
        null,
        {
          params: {
            apiKey,
            to: phone,
            content: `Your KAZI verification code is: ${otp}. Valid for ${this.OTP_EXPIRY_MINUTES} minutes. Do not share this code.`,
          },
        },
      );
    } catch (err) {
      this.logger.error(`Failed to send SMS to ${phone}`, err);
      throw new BadRequestException('Failed to send OTP. Please try again.');
    }
  }
}
