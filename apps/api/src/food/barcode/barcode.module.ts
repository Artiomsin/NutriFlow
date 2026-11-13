import { Module, type Provider } from '@nestjs/common';

import { env } from '../../config/env';
import { DbModule } from '../../db/db.module';
import { RedisModule } from '../../redis/redis.module';
import { RedisService } from '../../redis/redis.service';
import { BarcodeLookupService } from './barcode-lookup.service';
import { LocalDatabaseBarcodeProvider } from './local-database.barcode-provider';
import { OpenFoodFactsBarcodeProvider } from './open-food-facts.barcode-provider';

// The provider accepts an options object for direct unit-test construction.
// Register it through a factory so Nest does not attempt to resolve that
// object as a runtime dependency.
const openFoodFactsBarcodeProvider: Provider = {
  provide: OpenFoodFactsBarcodeProvider,
  useFactory: () => new OpenFoodFactsBarcodeProvider(),
};

const barcodeLookupServiceProvider: Provider = {
  provide: BarcodeLookupService,
  useFactory: (
    localProvider: LocalDatabaseBarcodeProvider,
    offProvider: OpenFoodFactsBarcodeProvider,
    redisService: RedisService,
  ) =>
    new BarcodeLookupService(redisService, [
      localProvider,
      // OFF is an external fallback: it only runs after the local database
      // missed, and its results are the reason caching is enabled.
      ...(env.OFF_ENABLED ? [offProvider] : []),
    ]),
  inject: [
    LocalDatabaseBarcodeProvider,
    OpenFoodFactsBarcodeProvider,
    RedisService,
  ],
};

@Module({
  imports: [DbModule, RedisModule],
  providers: [
    LocalDatabaseBarcodeProvider,
    openFoodFactsBarcodeProvider,
    barcodeLookupServiceProvider,
  ],
  exports: [BarcodeLookupService],
})
export class BarcodeModule {}
