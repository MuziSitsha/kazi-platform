import {
  Body,
  Controller,
  Get,
  Patch,
  Post,
  Query,
  Request,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { AuthGuard } from '@nestjs/passport';
import { ProvidersService } from './providers.service';
import { SubmitProviderDocumentsDto } from './dto/submit-provider-documents.dto';
import { UpsertProviderProfileDto } from './dto/upsert-provider-profile.dto';
import { UpdateAvailabilityDto } from './dto/update-availability.dto';

@ApiTags('providers')
@Controller('providers')
export class ProvidersController {
  constructor(private readonly providersService: ProvidersService) {}

  @Get()
  @ApiOperation({ summary: 'List approved providers' })
  listProviders(@Query('serviceCategoryId') serviceCategoryId?: string) {
    return this.providersService.listProviders(serviceCategoryId);
  }

  @Post('onboarding')
  @ApiBearerAuth()
  @UseGuards(AuthGuard('jwt'))
  @ApiOperation({ summary: 'Create or update provider onboarding profile' })
  onboard(@Request() req, @Body() dto: UpsertProviderProfileDto) {
    return this.providersService.onboard(req.user.id, dto);
  }

  @Get('me')
  @ApiBearerAuth()
  @UseGuards(AuthGuard('jwt'))
  @ApiOperation({ summary: 'Get current provider profile' })
  getMyProfile(@Request() req) {
    return this.providersService.getMyProfile(req.user.id);
  }

  @Patch('me')
  @ApiBearerAuth()
  @UseGuards(AuthGuard('jwt'))
  @ApiOperation({ summary: 'Update current provider profile' })
  updateMyProfile(@Request() req, @Body() dto: UpsertProviderProfileDto) {
    return this.providersService.updateProfile(req.user.id, dto);
  }

  @Patch('me/availability')
  @ApiBearerAuth()
  @UseGuards(AuthGuard('jwt'))
  @ApiOperation({ summary: 'Toggle provider availability' })
  updateAvailability(@Request() req, @Body() dto: UpdateAvailabilityDto) {
    return this.providersService.updateAvailability(req.user.id, dto.isAvailable);
  }

  @Post('me/documents')
  @ApiBearerAuth()
  @UseGuards(AuthGuard('jwt'))
  @ApiOperation({ summary: 'Submit provider verification documents' })
  submitDocuments(@Request() req, @Body() dto: SubmitProviderDocumentsDto) {
    return this.providersService.submitDocuments(req.user.id, dto.documents);
  }

  @Get('me/documents')
  @ApiBearerAuth()
  @UseGuards(AuthGuard('jwt'))
  @ApiOperation({ summary: 'List current provider verification documents' })
  listMyDocuments(@Request() req) {
    return this.providersService.listMyDocuments(req.user.id);
  }
}