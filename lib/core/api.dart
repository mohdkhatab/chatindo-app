import 'api_client.dart';
import 'session_controller.dart';

/// Facade covering every deployed Chatindo edge function.
class ChatindoApi {
  ChatindoApi(this.session);

  final SessionController session;

  ApiClient get api => session.api;

  // ---------------- users ----------------

  Future<ApiUser> me() async {
    final body = await session.guarded(() => api.get('users-me'));
    return ResponseParser.extract(body, 'user', ApiUser.fromJson);
  }

  Future<ApiUser> updateMe({String? displayName, String? username, String? bio, String? avatarUrl, String? statusMessage}) async {
    final body = await session.guarded(() => api.patch('users-me-update', body: {
          'display_name': displayName,
          'username': username,
          'bio': bio,
          'avatar_url': avatarUrl,
          'status_message': statusMessage,
        }));
    final user = body['user'] ?? body;
    if (user is Map) return ApiUser.fromJson(Map<String, dynamic>.from(user));
    throw ApiException('Malformed update response');
  }

  Future<List<ApiUser>> searchUsers(String q) async {
    final body = await session.guarded(() => api.get('users-search', query: {'q': q}));
    return ResponseParser.extractList(body, 'users', ApiUser.fromJson);
  }

  Future<ApiUser> getUser(String id) async {
    final body = await session.guarded(() => api.get('users-get/$id'));
    return ResponseParser.extract(body, 'user', ApiUser.fromJson);
  }

  Future<void> blockUser(String id) => session.guarded(() => api.post('users-block', body: {'user_id': id})).then((_) {});

  Future<void> unblockUser(String id) => session.guarded(() => api.post('users-unblock', body: {'user_id': id})).then((_) {});

  // ---------------- presence ----------------

  Future<void> ping({bool online = true}) =>
      session.guarded(() => api.post('presence-ping', body: {'online': online})).then((_) {});

  Future<void> typing(String chatId, {bool on = true}) => session
      .guarded(() => api.post('presence-typing', body: {'chat_id': chatId, 'is_typing': on}))
      .then((_) {});

  // ---------------- chats ----------------

  Future<ApiChat> directChat(String userId) async {
    final body = await session.guarded(() => api.post('chats-direct', body: {'user_id': userId}));
    return ResponseParser.extract(body, 'chat', ApiChat.fromJson);
  }

  Future<ApiChat> groupChat(String groupName, List<String> memberIds) async {
    final body = await session.guarded(() => api.post('chats-group', body: {'name': groupName, 'user_ids': memberIds}));
    return ResponseParser.extract(body, 'chat', ApiChat.fromJson);
  }

  Future<List<ApiChat>> chatsList() async {
    final body = await session.guarded(() => api.get('chats-list'));
    final raw = body['chats'];
    if (raw is List) {
      // Each chat row may nest `members` or contain peer info directly.
      return raw.map((e) => ApiChat.fromJson(_flattenChat(Map<String, dynamic>.from(e as Map)))).toList();
    }
    return const [];
  }

  Future<ApiChat> chatDetails(String id) async {
    final body = await session.guarded(() => api.get('chats-get/$id'));
    return ResponseParser.extract(body, 'chat', ApiChat.fromJson);
  }

  Future<void> updateChat(String id, {String? name, String? avatarUrl}) => session
      .guarded(() => api.patch('chats-update/$id', body: {'name': name, 'avatar_url': avatarUrl}))
      .then((_) {});

  Future<void> addMembers(String id, List<String> userIds) =>
      session.guarded(() => api.post('chats-members-add/$id', body: {'user_ids': userIds})).then((_) {});

  Future<void> removeMember(String id, String userId) =>
      session.guarded(() => api.post('chats-members-remove/$id', body: {'user_id': userId})).then((_) {});

  Future<void> leaveChat(String id) => session.guarded(() => api.post('chats-leave/$id', body: {})).then((_) {});

  // ---------------- messages ----------------

  Future<ApiMessage> sendMessage(String chatId, String ciphertext, {String? messageType, String? replyToId}) async {
    final body = await session.guarded(() => api.post('messages-send', body: {
          'chat_id': chatId,
          'ciphertext': ciphertext,
          'message_type': messageType ?? 'text',
          'reply_to_id': replyToId,
        }));
    return ApiMessage.fromJson(body['message'] is Map ? Map<String, dynamic>.from(body['message'] as Map) : body);
  }

  Future<List<ApiMessage>> messageHistory(String chatId, {String? before, int limit = 50}) async {
    final body = await session.guarded(() =>
        api.get('messages-history/$chatId', query: {'limit': '$limit', if (before != null) 'before': before}));
    return ResponseParser.extractList(body, 'messages', ApiMessage.fromJson);
  }

  Future<void> editMessage(String id, String ciphertext) =>
      session.guarded(() => api.put('messages-edit/$id', body: {'ciphertext': ciphertext})).then((_) {});

  Future<void> deleteMessage(String id, {bool everyone = true}) =>
      session.guarded(() => api.delete('messages-delete/$id', body: {'mode': everyone ? 'everyone' : 'me'})).then((_) {});

  Future<void> setStatus(String id, String status) => session
      .guarded(() => api.post('messages-status/$id', body: {'status': status}))
      .then((_) {});

  Future<bool> toggleReaction(String id, String emoji) async {
    final body = await session.guarded(() => api.post('messages-reaction/$id', body: {'emoji': emoji}));
    return body['reacted'] == true;
  }

  Future<List<ApiMessage>> searchMessages(String chatId, {String? q}) async {
    final body = await session.guarded(() => api.get('messages-search', query: {'chat_id': chatId, if (q != null) 'q': q}));
    return ResponseParser.extractList(body, 'results', ApiMessage.fromJson);
  }

  Future<String> uploadMedia(List<int> bytes, {String? name, String? folder}) async {
    final body = await session.guarded(() => api.uploadBytes('media-upload',
        bytes,
        query: {'name': name ?? 'media.bin', if (folder != null) 'folder': folder}));
    final url = body['url'] as String?;
    if (url == null) throw ApiException('Upload did not return a URL');
    return url;
  }

  // ---------------- calls ----------------

  Future<ApiCall> initiateCall(String chatId, String callType) async {
    final body = await session.guarded(() => api.post('calls-initiate', body: {'chat_id': chatId, 'call_type': callType}));
    return ResponseParser.extract(body, 'call', ApiCall.fromJson);
  }

  Future<void> answerCall(String id, {String? sdpAnswer}) => session
      .guarded(() => api.post('calls-answer/$id', body: {'sdp_answer': sdpAnswer}))
      .then((_) {});

  Future<void> rejectCall(String id) => session.guarded(() => api.post('calls-reject/$id', body: {})).then((_) {});

  Future<void> endCall(String id) => session.guarded(() => api.post('calls-end/$id', body: {})).then((_) {});

  Future<List<ApiCall>> callHistory() async {
    final body = await session.guarded(() => api.get('calls-history'));
    return ResponseParser.extractList(body, 'calls', ApiCall.fromJson);
  }

  // ---------------- notifications ----------------

  Future<void> registerPushToken(String token, {String? platform, String? deviceId}) => session
      .guarded(() => api.post('notifications-register-token', body: {'token': token, 'platform': platform, 'device_id': deviceId}))
      .then((_) {});

  Future<bool> notificationPref(String key) async {
    final body = await session.guarded(() => api.get('notifications-settings-get'));
    final settings = body['settings'] is Map ? (body['settings'] as Map).cast<String, dynamic>() : <String, dynamic>{};
    return settings[key] == true;
  }

  Future<void> setNotificationPrefs(Map<String, bool> prefs) =>
      session.guarded(() => api.put('notifications-settings-update', body: prefs)).then((_) {});

  // ---------------- premium ----------------

  Future<List<ApiPlan>> plans() async {
    final body = await api.get('premium-plans');
    return ResponseParser.extractList(body, 'plans', ApiPlan.fromJson);
  }

  Future<Map<String, dynamic>> premiumStatus() async {
    final body = await session.guarded(() => api.get('premium-status'));
    return body;
  }

  /// Passthrough for GET-only functions the facade does not model.
  Future<Map<String, dynamic>> rawGet(String name, {Map<String, String>? query}) {
    return session.guarded(() => api.get(name, query: query));
  }

  Future<void> subscribe(String planId) =>
      session.guarded(() => api.post('premium-subscribe', body: {'plan_id': planId})).then((_) {});

  Future<void> cancelPremium() => session.guarded(() => api.post('premium-cancel', body: {})).then((_) {});

  // ---------------- legal ----------------

  Future<String> legalDoc(String which) async {
    final body = await api.get(which == 'privacy' ? 'legal-privacy-policy' : 'legal-terms');
    final doc = (which == 'privacy' ? body['privacy_policy'] : body['terms']);
    if (doc is Map) {
      final sections = doc['sections'];
      if (sections is List) return sections.map((s) => '• $s\n').join();
    }
    return '';
  }

  Future<void> acceptLegal(String docId, {int version = 1}) =>
      session.guarded(() => api.post('legal-accept', body: {'doc_id': docId, 'version': version})).then((_) {});

  // ---------------- helpers ----------------

  /// chats-list returns rows where `members` may nest `chat_member.user`.
  static Map<String, dynamic> _flattenChat(Map<String, dynamic> row) {
    final members = row['members'];
    if (members is List) {
      final flat = <ApiUser>[];
      for (final m in members) {
        if (m is Map) {
          final user = m['user'];
          if (user is Map) {
            flat.add(ApiUser.fromJson(Map<String, dynamic>.from(user)));
          }
        }
      }
      row['members'] = flat.map((u) => {
            'id': u.id,
            'username': u.username,
            'display_name': u.displayName,
          }).toList();
    }
    return row;
  }
}