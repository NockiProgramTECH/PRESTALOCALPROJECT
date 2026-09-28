/// Expéditeur d'un message
enum MessageSender { user, provider }

/// Modèle représentant un message dans une conversation
///
/// Peut être envoyé par l'utilisateur ou par le prestataire.
/// Correspond au schéma `Message` de l'API Messagerie :
/// `{ id, sender_id, content, created_at }`.
class MessageModel {
  final String id;
  final String text;
  final MessageSender sender;
  final DateTime timestamp;
  final bool isRead;

  /// Vrai si l'envoi local a échoué (affichage d'un état d'erreur).
  final bool isFailed;

  const MessageModel({
    required this.id,
    required this.text,
    required this.sender,
    required this.timestamp,
    this.isRead = true,
    this.isFailed = false,
  });

  /// Construit un message depuis la réponse de l'API.
  ///
  /// [selfUserId] (UUID du user connecté, comparé **en chaîne**) détermine si
  /// le message est de l'utilisateur (`user`) ou du prestataire (`provider`).
  factory MessageModel.fromJson(
    Map<String, dynamic> json, {
    required String selfUserId,
  }) {
    final senderId = json['sender_id']?.toString();
    return MessageModel(
      id: json['id'].toString(),
      text: json['content']?.toString() ?? json['text']?.toString() ?? '',
      sender: senderId == selfUserId
          ? MessageSender.user
          : MessageSender.provider,
      timestamp:
          DateTime.tryParse(json['created_at']?.toString() ?? '')?.toLocal() ??
              DateTime.now(),
      isRead: json['is_read'] as bool? ?? true,
    );
  }

  MessageModel copyWith({bool? isFailed, String? id, bool? isRead}) {
    return MessageModel(
      id: id ?? this.id,
      text: text,
      sender: sender,
      timestamp: timestamp,
      isRead: isRead ?? this.isRead,
      isFailed: isFailed ?? this.isFailed,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'sender': sender == MessageSender.provider ? 'provider' : 'user',
      'timestamp': timestamp.toIso8601String(),
      'is_read': isRead,
    };
  }
}
