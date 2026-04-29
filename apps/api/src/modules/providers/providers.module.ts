import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { UserEntity } from '../users/entities/user.entity';
import { ProviderDocumentStorageService } from './provider-document-storage.service';
import { ProvidersController } from './providers.controller';
import { ProvidersService } from './providers.service';
import { ProviderDocumentEntity } from './entities/provider-document.entity';
import { ProviderProfileEntity } from './entities/provider-profile.entity';

@Module({
	imports: [TypeOrmModule.forFeature([ProviderProfileEntity, ProviderDocumentEntity, UserEntity])],
	controllers: [ProvidersController],
	providers: [ProvidersService, ProviderDocumentStorageService],
	exports: [ProvidersService, TypeOrmModule],
})
export class ProvidersModule {}