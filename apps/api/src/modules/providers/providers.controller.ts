import {
  Body,
  Controller,
  Get,
  HttpCode,
  Patch,
  Post,
  Query,
  Request,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiBody,
  ApiConsumes,
  ApiOperation,
  ApiTags,
} from '@nestjs/swagger';
import { AuthGuard } from '@nestjs/passport';
import { FileInterceptor } from '@nestjs/platform-express';
import { ProvidersService } from './providers.service';
import { SubmitProviderDocumentsDto } from './dto/submit-provider-documents.dto';
import { UploadProviderDocumentDto } from './dto/upload-provider-document.dto';
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

  @Post('me/documents/upload')
  @HttpCode(201)
  @ApiBearerAuth()
  @UseGuards(AuthGuard('jwt'))
  @UseInterceptors(FileInterceptor('file'))
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      required: ['documentType', 'file'],
      properties: {
        documentType: { type: 'string', example: 'national_id' },
        file: { type: 'string', format: 'binary' },
      },
    },
  })
  @ApiOperation({ summary: 'Upload a provider verification document to S3' })
  uploadDocument(
    @Request() req,
    @Body() dto: UploadProviderDocumentDto,
    @UploadedFile() file: Express.Multer.File,
  ) {
    return this.providersService.uploadDocument(req.user.id, dto.documentType, file);
  }

  @Get('me/documents')
  @ApiBearerAuth()
  @UseGuards(AuthGuard('jwt'))
  @ApiOperation({ summary: 'List current provider verification documents' })
  listMyDocuments(@Request() req) {
    return this.providersService.listMyDocuments(req.user.id);
  }
}