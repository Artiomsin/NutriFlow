import { Module, Global } from '@nestjs/common';
import { db } from './db';

@Global()
@Module({
  providers: [
    {
      provide: 'DB',
      useValue: db,
    },
  ],
  exports: ['DB'],
})
export class DbModule {}
