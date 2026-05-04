import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddBusinessPayoutFieldsToPlatformSettings1714856400000 implements MigrationInterface {
  name = 'AddBusinessPayoutFieldsToPlatformSettings1714856400000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`ALTER TABLE "platform_settings" ADD COLUMN IF NOT EXISTS "businessLegalName" character varying`);
    await queryRunner.query(`ALTER TABLE "platform_settings" ADD COLUMN IF NOT EXISTS "payoutBankName" character varying`);
    await queryRunner.query(`ALTER TABLE "platform_settings" ADD COLUMN IF NOT EXISTS "payoutAccountHolder" character varying`);
    await queryRunner.query(`ALTER TABLE "platform_settings" ADD COLUMN IF NOT EXISTS "payoutAccountNumber" character varying`);
    await queryRunner.query(`ALTER TABLE "platform_settings" ADD COLUMN IF NOT EXISTS "payoutAccountType" character varying`);
    await queryRunner.query(`ALTER TABLE "platform_settings" ADD COLUMN IF NOT EXISTS "payoutBranchCode" character varying`);
    await queryRunner.query(`ALTER TABLE "platform_settings" ADD COLUMN IF NOT EXISTS "payoutReference" character varying`);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`ALTER TABLE "platform_settings" DROP COLUMN IF EXISTS "payoutReference"`);
    await queryRunner.query(`ALTER TABLE "platform_settings" DROP COLUMN IF EXISTS "payoutBranchCode"`);
    await queryRunner.query(`ALTER TABLE "platform_settings" DROP COLUMN IF EXISTS "payoutAccountType"`);
    await queryRunner.query(`ALTER TABLE "platform_settings" DROP COLUMN IF EXISTS "payoutAccountNumber"`);
    await queryRunner.query(`ALTER TABLE "platform_settings" DROP COLUMN IF EXISTS "payoutAccountHolder"`);
    await queryRunner.query(`ALTER TABLE "platform_settings" DROP COLUMN IF EXISTS "payoutBankName"`);
    await queryRunner.query(`ALTER TABLE "platform_settings" DROP COLUMN IF EXISTS "businessLegalName"`);
  }
}