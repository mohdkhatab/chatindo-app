import '../core/api_client.dart';

/// A chats-list row with an optional decrypted preview.
class ChatItem {
  ChatItem({required this.chat, this.lastMessage});

  final ApiChat chat;
  final String? lastMessage;

  String get subtitle => lastMessage ?? 'Encrypted';
}