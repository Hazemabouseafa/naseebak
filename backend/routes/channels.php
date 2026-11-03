<?php

use App\Services\Messaging\ConversationMessagingService;
use Illuminate\Support\Facades\Broadcast;

Broadcast::channel('conversation.{conversationId}', function ($user, int $conversationId) {
    return app(ConversationMessagingService::class)
        ->canSubscribeToConversationChannel($user, $conversationId);
});

Broadcast::channel('user.{userId}', function ($user, int $userId) {
    return $user->account_status === 'active'
        && (int) $user->id === (int) $userId;
});
