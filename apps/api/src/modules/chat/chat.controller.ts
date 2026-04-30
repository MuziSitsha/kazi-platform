import { Body, Controller, Get, Param, Post, Request, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { AuthGuard } from '@nestjs/passport';
import { SendChatMessageDto } from './dto/send-chat-message.dto';
import { ChatService } from './chat.service';

@ApiTags('chat')
@ApiBearerAuth()
@UseGuards(AuthGuard('jwt'))
@Controller('chat')
export class ChatController {
  constructor(private readonly chatService: ChatService) {}

  @Get('bookings/:bookingId/thread')
  @ApiOperation({ summary: 'Get the booking-scoped chat thread and participant details' })
  getBookingThread(@Request() req, @Param('bookingId') bookingId: string) {
    return this.chatService.getBookingThread(bookingId, req.user.id);
  }

  @Post('bookings/:bookingId/messages')
  @ApiOperation({ summary: 'Send a booking-scoped chat message' })
  sendMessage(@Request() req, @Param('bookingId') bookingId: string, @Body() dto: SendChatMessageDto) {
    return this.chatService.sendMessage(bookingId, req.user.id, dto.message);
  }

  @Post('bookings/:bookingId/call')
  @ApiOperation({ summary: 'Start a booking call and return the active call session details' })
  startCall(@Request() req, @Param('bookingId') bookingId: string) {
    return this.chatService.startCall(bookingId, req.user.id);
  }
}