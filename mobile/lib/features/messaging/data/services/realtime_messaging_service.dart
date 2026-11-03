import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../repositories/messaging_repository.dart';

enum RealtimeConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

class ReverbEventMessage {
  final String channel;
  final String event;
  final Map<String, dynamic> data;

  const ReverbEventMessage({
    String? channel,
    String? event,
    String? channelName,
    String? eventName,
    required this.data,
  })  : channel = channel ?? channelName ?? '',
        event = event ?? eventName ?? '';

  String get channelName => channel;
  String get eventName => event;
}

typedef RealtimeSocketEvent = ReverbEventMessage;

/// Injectable transport abstraction over `web_socket_channel` for Pusher/Reverb protocol v7.
abstract class ReverbSocketTransport {
  Stream<dynamic> get stream;
  void send(String data);
  Future<void> close();
}

class WebSocketChannelTransport implements ReverbSocketTransport {
  final WebSocketChannel _channel;

  WebSocketChannelTransport(Uri uri) : _channel = WebSocketChannel.connect(uri);

  @override
  Stream<dynamic> get stream => _channel.stream;

  @override
  void send(String data) => _channel.sink.add(data);

  @override
  Future<void> close() => _channel.sink.close();
}

final realtimeMessagingServiceProvider =
    Provider<RealtimeMessagingService>((ref) {
  final service = RealtimeMessagingService(
    repository: ref.watch(messagingRepositoryProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

/// Real-Time WebSocket Client compatible with Laravel Reverb (Pusher Protocol v7).
///
/// Responsibilities:
/// - Connects to Laravel Reverb over WSS/WS.
/// - Authenticates `private-conversation.{id}` and `private-user.{id}` channels
///   through `POST /api/v1/broadcasting/auth` using the Sanctum Bearer token.
/// - Prevents duplicate active subscriptions for the same channel.
/// - Automatically reconnects after disconnection and triggers resynchronization callbacks.
/// - Unsubscribes cleanly when leaving conversations and disconnects on logout.
class RealtimeMessagingService {
  final MessagingRepository _repository;
  final ReverbSocketTransport Function(Uri uri) _transportFactory;

  ReverbSocketTransport? _transport;
  StreamSubscription<dynamic>? _socketSubscription;
  Timer? _reconnectTimer;

  RealtimeConnectionState _connectionState =
      RealtimeConnectionState.disconnected;
  String? _socketId;
  bool _manualDisconnect = false;
  int _reconnectAttempts = 0;

  final Set<String> _desiredPrivateChannels = <String>{};
  final Set<String> _subscribedChannels = <String>{};

  final StreamController<RealtimeConnectionState> _connectionController =
      StreamController<RealtimeConnectionState>.broadcast();
  final StreamController<ReverbEventMessage> _eventsController =
      StreamController<ReverbEventMessage>.broadcast();
  final StreamController<void> _reconnectedController =
      StreamController<void>.broadcast();

  RealtimeMessagingService({
    required MessagingRepository repository,
    ReverbSocketTransport Function(Uri uri)? transportFactory,
  })  : _repository = repository,
        _transportFactory = transportFactory ??
            ((uri) => WebSocketChannelTransport(uri));

  RealtimeConnectionState get connectionState => _connectionState;
  String? get socketId => _socketId;
  Set<String> get subscribedChannels => Set.unmodifiable(_subscribedChannels);

  Stream<RealtimeConnectionState> get connectionStateStream =>
      _connectionController.stream;
  Stream<ReverbEventMessage> get eventsStream => _eventsController.stream;
  Stream<ReverbEventMessage> get events => _eventsController.stream;
  Stream<void> get onReconnectedStream => _reconnectedController.stream;

  Future<void> connectForUser(int userId) async {
    await connect();
    await subscribeToUserChannel(userId);
  }

  Future<void> disconnect() => disconnectOnLogout();

  Future<void> connect() async {
    if (_connectionState == RealtimeConnectionState.connected ||
        _connectionState == RealtimeConnectionState.connecting) {
      return;
    }

    _manualDisconnect = false;
    _setConnectionState(
      _reconnectAttempts > 0
          ? RealtimeConnectionState.reconnecting
          : RealtimeConnectionState.connecting,
    );

    try {
      final uri = Uri.parse(ApiEndpoints.reverbWsUrl);
      _transport = _transportFactory(uri);
      _socketSubscription = _transport!.stream.listen(
        _handleRawSocketFrame,
        onError: (_) => _scheduleReconnect(),
        onDone: () {
          if (!_manualDisconnect) {
            _scheduleReconnect();
          }
        },
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  Future<void> subscribeToUserChannel(int userId) async {
    final channelName = 'private-user.$userId';
    _desiredPrivateChannels.add(channelName);
    await _ensureChannelSubscribed(channelName);
  }

  Future<void> subscribeToConversation(int conversationId) async {
    final channelName = 'private-conversation.$conversationId';
    _desiredPrivateChannels.add(channelName);
    await _ensureChannelSubscribed(channelName);
  }

  void unsubscribeFromConversation(int conversationId) {
    final channelName = 'private-conversation.$conversationId';
    _desiredPrivateChannels.remove(channelName);

    if (_subscribedChannels.remove(channelName) && _transport != null) {
      _transport!.send(
        jsonEncode({
          'event': 'pusher:unsubscribe',
          'data': {'channel': channelName},
        }),
      );
    }
  }

  Future<void> _ensureChannelSubscribed(String channelName) async {
    // Prevent duplicate active subscriptions for the same channel
    if (_subscribedChannels.contains(channelName)) {
      return;
    }

    if (_connectionState != RealtimeConnectionState.connected ||
        _socketId == null) {
      await connect();
      return;
    }

    try {
      final authSignature = await _repository.authorizePrivateChannel(
        socketId: _socketId!,
        channelName: channelName,
      );
      if (authSignature.isEmpty || _transport == null) return;

      _subscribedChannels.add(channelName);
      _transport!.send(
        jsonEncode({
          'event': 'pusher:subscribe',
          'data': {
            'channel': channelName,
            'auth': authSignature,
          },
        }),
      );
    } catch (_) {
      // Unauthorized or transient failure: do not mark channel as subscribed
      _subscribedChannels.remove(channelName);
    }
  }

  Future<void> _handleRawSocketFrame(dynamic rawFrame) async {
    if (rawFrame is! String) return;

    Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(rawFrame) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    final eventName = (decoded['event'] as String?) ?? '';
    final channelName = (decoded['channel'] as String?) ?? '';
    final rawData = decoded['data'];

    Map<String, dynamic> payloadData = const <String, dynamic>{};
    if (rawData is String && rawData.isNotEmpty) {
      try {
        final parsed = jsonDecode(rawData);
        if (parsed is Map<String, dynamic>) {
          payloadData = parsed;
        }
      } catch (_) {}
    } else if (rawData is Map<String, dynamic>) {
      payloadData = rawData;
    }

    if (eventName == 'pusher:connection_established') {
      final wasReconnecting = _reconnectAttempts > 0;
      _socketId = payloadData['socket_id'] as String?;
      _reconnectAttempts = 0;
      _subscribedChannels.clear();
      _setConnectionState(RealtimeConnectionState.connected);

      // Restore all authorized private channel subscriptions
      for (final channel in _desiredPrivateChannels.toList()) {
        await _ensureChannelSubscribed(channel);
      }

      if (wasReconnecting) {
        _reconnectedController.add(null);
      }
      return;
    }

    if (eventName == 'pusher:ping') {
      _transport?.send(jsonEncode({'event': 'pusher:pong', 'data': {}}));
      return;
    }

    if (eventName.startsWith('pusher:') ||
        eventName.startsWith('pusher_internal:')) {
      return;
    }

    _eventsController.add(
      ReverbEventMessage(
        channel: channelName,
        event: eventName,
        data: payloadData,
      ),
    );
  }

  void _scheduleReconnect() {
    if (_manualDisconnect) return;

    _socketId = null;
    _subscribedChannels.clear();
    _socketSubscription?.cancel();
    _socketSubscription = null;
    _transport = null;

    _reconnectAttempts += 1;
    _setConnectionState(RealtimeConnectionState.reconnecting);

    _reconnectTimer?.cancel();
    final delaySeconds = (_reconnectAttempts * 2).clamp(2, 15);
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      if (!_manualDisconnect) {
        connect();
      }
    });
  }

  Future<void> disconnectOnLogout() async {
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _desiredPrivateChannels.clear();
    _subscribedChannels.clear();
    _socketId = null;
    _reconnectAttempts = 0;

    await _socketSubscription?.cancel();
    _socketSubscription = null;
    await _transport?.close();
    _transport = null;

    _setConnectionState(RealtimeConnectionState.disconnected);
  }

  void _setConnectionState(RealtimeConnectionState next) {
    _connectionState = next;
    if (!_connectionController.isClosed) {
      _connectionController.add(next);
    }
  }

  void dispose() {
    disconnectOnLogout();
    _connectionController.close();
    _eventsController.close();
    _reconnectedController.close();
  }
}
