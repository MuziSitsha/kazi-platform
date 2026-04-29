import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Request,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { AuthGuard } from '@nestjs/passport';
import { AdminService } from './admin.service';
import { ReviewProviderVerificationDto } from './dto/review-provider-verification.dto';
import { UpdatePlatformSettingsDto } from './dto/update-platform-settings.dto';

@ApiTags('admin')
@ApiBearerAuth()
@UseGuards(AuthGuard('jwt'))
@Controller('admin')
export class AdminController {
  constructor(private readonly adminService: AdminService) {}

  @Get('settings')
  @ApiOperation({ summary: 'Get platform settings' })
  getSettings() {
    return this.adminService.getSettings();
  }

  @Patch('settings')
  @ApiOperation({ summary: 'Update platform settings as an admin' })
  updateSettings(@Request() req, @Body() dto: UpdatePlatformSettingsDto) {
    return this.adminService.updateSettings(req.user, dto);
  }

  @Get('providers/pending-verification')
  @ApiOperation({ summary: 'List providers waiting for verification review' })
  listPendingProviderVerifications(@Request() req) {
    return this.adminService.listPendingProviderVerifications(req.user.role);
  }

  @Patch('providers/:providerUserId/verification')
  @ApiOperation({ summary: 'Approve or reject provider verification' })
  reviewProviderVerification(
    @Request() req,
    @Param('providerUserId') providerUserId: string,
    @Body() dto: ReviewProviderVerificationDto,
  ) {
    return this.adminService.reviewProviderVerification(req.user, providerUserId, dto);
  }
}