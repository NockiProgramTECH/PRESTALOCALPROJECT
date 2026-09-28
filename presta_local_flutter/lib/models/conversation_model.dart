import '../utils/media.dart';
import 'category_model.dart';
import 'message_model.dart';
import 'provider_model.dart';

/// Modèle représentant une conversation entre l'utilisateur et un prestataire
///
/// Contient la liste des messages, le prestataire associé (participant),
/// et des métadonnées comme le nombre de messages non lus.
/// Correspond aux schémas `Conversation` de l'API Messagerie.
class ConversationModel {
  final String id;
  final ProviderModel provider;
  final List<MessageModel> messages;
  final MessageModel? lastMessage;
  final int unreadCount;
  final bool isOnline;

  const ConversationModel({
    required this.id,
    required this.provider,
    required this.messages,
    this.lastMessage,
    this.unreadCount = 0,
    this.isOnline = false,
  });

  DateTime? get lastMessageTime => lastMessage?.timestamp;

  /// Construit une conversation depuis la **liste** de l'API :
  /// `{ id, participant, last_message, unread_count, updated_at }`.
  factory ConversationModel.fromListJson(
    Map<String, dynamic> json, {
    required String selfUserId,
  }) {
    final lastMessageRaw = json['last_message'];
    return ConversationModel(
      id: json['id'].toString(),
      provider: _providerFromParticipant(
        json['participant'] as Map<String, dynamic>? ?? const {},
      ),
      messages: const [],
      lastMessage: lastMessageRaw is Map<String, dynamic>
          ? MessageModel.fromJson(lastMessageRaw, selfUserId: selfUserId)
          : null,
      unreadCount: json['unread_count'] as int? ?? 0,
    );
  }

  /// Construit une conversation depuis le **détail** de l'API :
  /// `{ id, participant, messages }`.
  factory ConversationModel.fromJson(
    Map<String, dynamic> json, {
    required String selfUserId,
  }) {
    final messages = (json['messages'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((m) => MessageModel.fromJson(m, selfUserId: selfUserId))
        .toList();
    return ConversationModel(
      id: json['id'].toString(),
      provider: _providerFromParticipant(
        json['participant'] as Map<String, dynamic>? ?? const {},
      ),
      messages: messages,
      lastMessage: messages.isNotEmpty ? messages.last : null,
      unreadCount: json['unread_count'] as int? ?? 0,
    );
  }

  ConversationModel copyWith({
    List<MessageModel>? messages,
    MessageModel? lastMessage,
    int? unreadCount,
    bool? isOnline,
  }) {
    return ConversationModel(
      id: id,
      provider: provider,
      messages: messages ?? this.messages,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      isOnline: isOnline ?? this.isOnline,
    );
  }

  /// Construit un [ProviderModel] minimal à partir du participant de la
  /// conversation (`{ id, first_name, last_name, full_name, photo_url, role }`).
  static ProviderModel _providerFromParticipant(Map<String, dynamic> p) {
    final name = p['full_name']?.toString() ??
        '${p['first_name']?.toString() ?? ''} ${p['last_name']?.toString() ?? ''}'
            .trim();
    return ProviderModel(
      id: p['id'].toString(),
      name: name,
      title: '',
      category: const CategoryModel(
        id: '',
        name: '',
        icon: 'handyman',
        description: '',
      ),
      rating: 0,
      reviewCount: 0,
      location: '',
      locationZone: '',
      avatar: resolveMediaUrl(p['photo_url']?.toString()),
      banner: '',
      about: '',
      priceText: '',
      services: const [],
      realisations: const [],
      reviews: const [],
      phone: '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'provider': provider.toJson(),
      'messages': messages.map((m) => m.toJson()).toList(),
      'unread_count': unreadCount,
      'is_online': isOnline,
    };
  }
}
