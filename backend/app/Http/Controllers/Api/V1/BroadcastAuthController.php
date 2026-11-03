<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Services\Messaging\ConversationMessagingService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class BroadcastAuthController extends Controller
{
    public function __construct(
        private readonly ConversationMessagingService $messagingService
    ) {}

    /**
     * POST /api/v1/broadcasting/auth
     *
     * Authenticates Laravel Reverb / Pusher-protocol private WebSocket channels
     * (`private-conversation.{conversationId}` and `private-user.{userId}`)
     * using the mobile client's Laravel Sanctum Bearer token.
     */
    public function authenticate(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'socket_id' => ['required', 'string', 'regex:/^\d+\.\d+$/'],
            'channel_name' => ['required', 'string', 'max:191'],
        ]);

        /** @var User $user */
        $user = $request->user();
        if (!$user || $user->account_status !== 'active') {
            return response()->json([
                'status' => 'error',
                'code' => 'CHANNEL_AUTH_FORBIDDEN',
                'message' => 'غير مصرح لك بالاشتراك في القناة الفورية.',
            ], 403);
        }

        $channelName = trim($validated['channel_name']);
        $socketId = trim($validated['socket_id']);

        $authorized = false;

        if (preg_match('/^private-conversation\.(\d+)$/', $channelName, $matches)) {
            $conversationId = (int) $matches[1];
            $authorized = $this->messagingService->canSubscribeToConversationChannel($user, $conversationId);
        } elseif (preg_match('/^private-user\.(\d+)$/', $channelName, $matches)) {
            $targetUserId = (int) $matches[1];
            $authorized = (int) $user->id === $targetUserId;
        }

        if (!$authorized) {
            return response()->json([
                'status' => 'error',
                'code' => 'CHANNEL_SUBSCRIPTION_FORBIDDEN',
                'message' => 'غير مصرح لك بالاشتراك في هذه القناة الخاصة.',
            ], 403);
        }

        $appKey = (string) config('broadcasting.connections.reverb.key', 'naseebak-reverb-key');
        $appSecret = (string) config('broadcasting.connections.reverb.secret', 'naseebak-reverb-secret');
        $signature = hash_hmac('sha256', "{$socketId}:{$channelName}", $appSecret);

        return response()->json([
            'auth' => "{$appKey}:{$signature}",
        ]);
    }
}
