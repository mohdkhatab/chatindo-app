import 'dart:async';

import 'package:realtime_client/realtime_client.dart';

import '../config/env.dart';

class RealtimeTyping {
  RealtimeTyping({required this.userId, required this.isTyping});
  final String userId;
  final bool isTyping;
}

/// Wraps Supabase Realtime (Postgres Changes) for live messaging.
/// - messages      subscribed per chat (realtime:public:messages)
/// - typing_events (realtime:public:typing_events)
/// - users         for presence (realtime:public:users)
class RealtimeService {
  RealtimeClient? _client;
  final Map<String, RealtimeChannel> _channels = {};
  final Map<String, StreamController<Map<String, dynamic>>> _controllers = {};

  /// Connect (or reconnect) with a fresh user JWT.
  void wire(String jwt) {
    unwire();
    _client = RealtimeClient(
      AppConfig.realtimeUrl,
      params: {'apikey': AppConfig.anonKey},
      headers: {'apikey': AppConfig.anonKey, 'Authorization': 'Bearer $jwt'},
    );
  }

  Stream<Map<String, dynamic>> onMessages(final String chatId) {
    return _listen<Map<String, dynamic>>('msgs:$chatId', 'realtime:public:messages', (channel, onData) {
      channel
          .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'messages',
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'chat_id', value: chatId),
        callback: (payload) {
          if (payload.newRecord != null) {
            final rec = Map<String, dynamic>.from(payload.newRecord!);
            // Realtime delivers snake_case rows; keep as-is for ApiMessage.
            onData(rec);
          }
        },
      )
          .subscribe();
    });
  }

  Stream<RealtimeTyping> onTyping(final String chatId) {
    return _listen<RealtimeTyping>('typing:$chatId', 'realtime:public:typing_events', (channel, onData) {
      channel
          .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'typing_events',
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'chat_id', value: chatId),
        callback: (payload) {
          final rec = payload.newRecord;
          if (rec != null) {
            onData(RealtimeTyping(
              userId: rec['user_id']?.toString() ?? '',
              isTyping: rec['is_typing'] == true,
            ));
          }
        },
      )
          .subscribe();
    });
  }

  /// Presence: observe users table changes (is_online toggles).
  Stream<Map<String, dynamic>> onPresence() {
    final key = 'realtime:public:users';
    final controller = _ensure<Map<String, dynamic>>(key);
    _channels.putIfAbsent(key, () {
      final channel = _client!.channel(key);
      channel
          .onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'users',
        callback: (payload) {
          final rec = payload.newRecord;
          if (rec != null) controller.add(Map<String, dynamic>.from(rec));
        },
      )
          .subscribe();
      return channel;
    });
    return controller.stream;
  }

  Stream<T> _listen<T>(
    String storageKey,
    String channelName,
    void Function(RealtimeChannel channel, void Function(T) onData) setup,
  ) {
    final controller = _ensure<T>(storageKey);
    if (!_channels.containsKey(storageKey)) {
      final channel = _client!.channel(channelName);
      setup(channel, controller.add);
      _channels[storageKey] = channel;
    }
    return controller.stream;
  }

  StreamController<T> _ensure<T>(String key) {
    if (_controllers[key] == null) {
      _controllers[key] = StreamController<T>.broadcast();
    }
    return _controllers[key] as StreamController<T>;
  }

  void unwire() {
    for (final c in _channels.values) {
      c.unsubscribe();
    }
    _channels.clear();
    for (final c in _controllers.values) {
      if (!c.isClosed) c.close();
    }
    _controllers.clear();
    try {
      _client?.disconnect();
    } catch (_) {}
    _client = null;
  }

  void dispose() {
    unwire();
  }
}