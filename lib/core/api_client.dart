import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/env.dart';

/// Thrown when the edge function returns a non-2xx or the network fails.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.code});

  final String message;
  final int? statusCode;
  final String? code;

  @override
  String toString() => message;
}

/// Minimal typed wrappers for the API responses we need.
class ApiUser {
  ApiUser({required this.id, this.username, this.displayName, this.avatarUrl, this.bio, this.isOnline, this.lastSeen, this.statusMessage, this.devicePublicKey});

  final String id;
  final String? username;
  final String? displayName;
  final String? avatarUrl;
  final String? bio;
  final bool? isOnline;
  final String? lastSeen;
  final String? statusMessage;
  final String? devicePublicKey;

  String get name => (displayName?.isNotEmpty ?? false) ? displayName! : (username ?? 'User');

  factory ApiUser.fromJson(Map<String, dynamic> json) => ApiUser(
        id: json['id'] as String? ?? '',
        username: json['username'] as String?,
        displayName: json['display_name'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        bio: json['bio'] as String?,
        isOnline: json['is_online'] as bool?,
        lastSeen: json['last_seen'] as String?,
        statusMessage: json['status_message'] as String?,
        devicePublicKey: json['device_public_key'] as String?,
      );
}

class ApiChat {
  ApiChat({required this.id, this.name, this.chatType, this.avatarUrl, this.lastMessageAt, this.memberCount, this.customData, this.members = const []});

  final String id;
  final String? name;
  final String? chatType;
  final String? avatarUrl;
  final String? lastMessageAt;
  final int? memberCount;
  final Map<String, dynamic>? customData;
  final List<ApiUser> members;

  String get title {
    if (name != null && name!.isNotEmpty) return name!;
    if (chatType == 'direct') {
      // For direct chats the list payload usually carries the peer info.
      final peer = members.isNotEmpty ? members.first : null;
      return peer?.name ?? 'Chat';
    }
    return 'Group';
  }

  factory ApiChat.fromJson(Map<String, dynamic> json) => ApiChat(
        id: json['id'] as String? ?? '',
        name: json['name'] as String?,
        chatType: json['chat_type'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        lastMessageAt: json['last_message_at'] as String?,
        memberCount: (json['member_count'] as num?)?.toInt(),
        customData: json['custom_data'] is Map<String, dynamic> ? json['custom_data'] as Map<String, dynamic> : null,
        members: ((json['members'] ?? []) as List)
            .whereType<Map>()
            .map((e) => ApiUser.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

class ApiMessage {
  ApiMessage({required this.id, required this.chatId, required this.senderId, this.messageType, this.ciphertext, this.mediaUrl, this.replyToId, this.createdAt, this.editedAt, this.isDeleted, this.encMetadata, this.sender});

  final String id;
  final String chatId;
  final String senderId;
  final String? messageType;
  final String? ciphertext;
  final String? mediaUrl;
  final String? replyToId;
  final String? createdAt;
  final String? editedAt;
  final bool? isDeleted;
  final Map<String, dynamic>? encMetadata;
  final ApiUser? sender;

  factory ApiMessage.fromJson(Map<String, dynamic> json) => ApiMessage(
        id: json['id'] as String? ?? '',
        chatId: json['chat_id'] as String? ?? '',
        senderId: json['sender_id'] as String? ?? '',
        messageType: json['message_type'] as String?,
        ciphertext: json['ciphertext'] as String?,
        mediaUrl: json['media_url'] as String?,
        replyToId: json['reply_to_id'] as String?,
        createdAt: json['created_at'] as String?,
        editedAt: json['edited_at'] as String?,
        isDeleted: json['is_deleted'] as bool?,
        encMetadata: json['enc_metadata'] is Map<String, dynamic> ? json['enc_metadata'] as Map<String, dynamic> : null,
        sender: json['sender'] is Map<String, dynamic> ? ApiUser.fromJson(json['sender'] as Map<String, dynamic>) : null,
      );
}

class ApiCall {
  ApiCall({required this.id, this.chatId, this.callerId, this.callType, this.status, this.createdAt, this.startedAt, this.endedAt});

  final String id;
  final String? chatId;
  final String? callerId;
  final String? callType;
  final String? status;
  final String? createdAt;
  final String? startedAt;
  final String? endedAt;

  factory ApiCall.fromJson(Map<String, dynamic> json) => ApiCall(
        id: json['id'] as String? ?? '',
        chatId: json['chat_id'] as String?,
        callerId: json['caller_id'] as String?,
        callType: json['call_type'] as String?,
        status: json['status'] as String?,
        createdAt: json['created_at'] as String?,
        startedAt: json['started_at'] as String?,
        endedAt: json['ended_at'] as String?,
      );
}

class ApiPlan {
  ApiPlan({required this.id, required this.name, required this.price, this.currency, this.period});

  final String id;
  final String name;
  final int price;
  final String? currency;
  final String? period;

  factory ApiPlan.fromJson(Map<String, dynamic> json) => ApiPlan(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        price: (json['price'] as num?)?.toInt() ?? 0,
        currency: json['currency'] as String?,
        period: json['period'] as String?,
      );
}

/// Also parses the missing-person mini models used by chats-list.
class ResponseParser {
  static T extract<T>(Map<String, dynamic> body, String key, T Function(Map<String, dynamic>) fromJson) {
    final v = body[key];
    if (v is Map) return fromJson(Map<String, dynamic>.from(v));
    throw ApiException('Malformed response: missing $key');
  }

  static List<T> extractList<T>(Map<String, dynamic> body, String key, T Function(Map<String, dynamic>) fromJson) {
    final v = body[key];
    if (v is List) return v.whereType<Map>().map((e) => fromJson(Map<String, dynamic>.from(e))).toList();
    return const [];
  }
}

/// HTTP client for the Chatindo edge-function API.
class ApiClient {
  ApiClient({String? base, http.Client? inner}) : _inner = inner ?? http.Client(), _base = base ?? AppConfig.functionBase;

  final String _base;
  final http.Client _inner;

  /// Bearer token set whenever a session is active.
  String? accessToken;
  String? refreshToken;

  Map<String, String> _headers({bool json = true}) {
    final h = <String, String>{'Accept': 'application/json'};
    if (json) h['Content-Type'] = 'application/json';
    if (accessToken != null && accessToken!.isNotEmpty) h['Authorization'] = 'Bearer $accessToken';
    return h;
  }

  Future<Map<String, dynamic>> get(String path, {Map<String, String>? query}) async {
    final uri = Uri.parse('$_base/$path').replace(queryParameters: query);
    final res = await _inner.get(uri, headers: _headers());
    return _decode(res);
  }

  Future<Map<String, dynamic>> post(String path, {Object? body, Map<String, String>? query}) async {
    final uri = Uri.parse('$_base/$path').replace(queryParameters: query);
    final res = await _inner.post(uri, headers: _headers(), body: jsonEncode(body ?? {}));
    return _decode(res);
  }

  Future<Map<String, dynamic>> put(String path, {Object? body}) async {
    final uri = Uri.parse('$_base/$path');
    final res = await _inner.put(uri, headers: _headers(), body: jsonEncode(body ?? {}));
    return _decode(res);
  }

  Future<Map<String, dynamic>> patch(String path, {Object? body}) async {
    final uri = Uri.parse('$_base/$path');
    final res = await _inner.patch(uri, headers: _headers(), body: jsonEncode(body ?? {}));
    return _decode(res);
  }

  Future<Map<String, dynamic>> delete(String path, {Object? body}) async {
    final uri = Uri.parse('$_base/$path');
    final res = await _inner.delete(uri, headers: _headers(), body: jsonEncode(body ?? {}));
    return _decode(res);
  }

  /// Uploads raw bytes (media-upload endpoint takes octet-stream).
  Future<Map<String, dynamic>> uploadBytes(String path, List<int> bytes, {Map<String, String>? query}) async {
    final uri = Uri.parse('$_base/$path').replace(queryParameters: query);
    final res = await _inner.post(
      uri,
      headers: {'Content-Type': 'application/octet-stream', 'Authorization': 'Bearer ${accessToken ?? ""}'},
      body: bytes,
    );
    return _decode(res);
  }

  Map<String, dynamic> _decode(http.Response res) {
    Map<String, dynamic> body;
    try {
      body = (jsonDecode(utf8.decode(res.bodyBytes)) as Map).cast<String, dynamic>();
    } catch (_) {
      body = {'error': 'Unparseable response', 'raw': res.body};
    }
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return body;
    }
    throw ApiException(
      (body['error'] as String?) ?? 'Request failed',
      statusCode: res.statusCode,
      code: body['code'] as String?,
    );
  }
}