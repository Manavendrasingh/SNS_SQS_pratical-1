import { Module } from '@nestjs/common';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { LambdaModule } from './lambda/lambda.module';

@Module({
  imports: [LambdaModule],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
