import 'package:flutter/material.dart';

class SupportTicketReplyModel {
  final int id;
  final String senderType; // 'member' | 'admin'
  final String senderName;
  final String body;
  final String? createdAt;

  const SupportTicketReplyModel({
    required this.id,
    required this.senderType,
    required this.senderName,
    required this.body,
    this.createdAt,
  });

  bool get isFromAdmin => senderType == 'admin';

  DateTime? get createdAtDateTime =>
      createdAt != null ? DateTime.tryParse(createdAt!) : null;

  factory SupportTicketReplyModel.fromJson(Map<String, dynamic> json) {
    return SupportTicketReplyModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      senderType: (json['sender_type'] ?? 'member').toString(),
      senderName: (json['sender_name'] ?? 'إدارة نَصِيبُكَ').toString(),
      body: (json['body'] ?? '').toString(),
      createdAt: json['created_at']?.toString(),
    );
  }
}

class SupportTicketModel {
  final int id;
  final String ticketNumber;
  final String type; // 'inquiry' | 'complaint'
  final String typeLabel;
  final String category;
  final String categoryLabel;
  final String subject;
  final String message;
  final String status; // 'open' | 'in_progress' | 'answered' | 'closed'
  final String statusLabel;
  final String? adminReply;
  final String? respondedAt;
  final String? lastActivityAt;
  final String lastSenderType;
  final int repliesCount;
  final String? closedAt;
  final String? createdAt;
  final List<SupportTicketReplyModel> replies;

  const SupportTicketModel({
    required this.id,
    required this.ticketNumber,
    required this.type,
    required this.typeLabel,
    required this.category,
    required this.categoryLabel,
    required this.subject,
    required this.message,
    required this.status,
    required this.statusLabel,
    this.adminReply,
    this.respondedAt,
    this.lastActivityAt,
    this.lastSenderType = 'member',
    this.repliesCount = 0,
    this.closedAt,
    this.createdAt,
    this.replies = const [],
  });

  bool get isComplaint => type == 'complaint';
  bool get isClosed => status == 'closed';
  bool get hasAdminReply =>
      (adminReply != null && adminReply!.trim().isNotEmpty) ||
      status == 'answered' ||
      replies.any((r) => r.isFromAdmin);

  DateTime? get createdAtDateTime =>
      createdAt != null ? DateTime.tryParse(createdAt!) : null;

  DateTime? get lastActivityDateTime =>
      lastActivityAt != null ? DateTime.tryParse(lastActivityAt!) : null;

  factory SupportTicketModel.fromJson(Map<String, dynamic> json) {
    final rawReplies = json['replies'];
    final parsedReplies = rawReplies is List
        ? rawReplies
            .whereType<Map>()
            .map((e) =>
                SupportTicketReplyModel.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : const <SupportTicketReplyModel>[];

    final type = (json['type'] ?? 'inquiry').toString();
    final category = (json['category'] ?? 'general').toString();
    final status = (json['status'] ?? 'open').toString();

    return SupportTicketModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      ticketNumber: (json['ticket_number'] ?? '').toString(),
      type: type,
      typeLabel:
          (json['type_label'] ?? defaultTypeLabel(type)).toString(),
      category: category,
      categoryLabel:
          (json['category_label'] ?? defaultCategoryLabel(category)).toString(),
      subject: (json['subject'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      status: status,
      statusLabel:
          (json['status_label'] ?? defaultStatusLabel(status)).toString(),
      adminReply: json['admin_reply']?.toString(),
      respondedAt: json['responded_at']?.toString(),
      lastActivityAt: json['last_activity_at']?.toString(),
      lastSenderType: (json['last_sender_type'] ?? 'member').toString(),
      repliesCount:
          (json['replies_count'] as num?)?.toInt() ?? parsedReplies.length,
      closedAt: json['closed_at']?.toString(),
      createdAt: json['created_at']?.toString(),
      replies: parsedReplies,
    );
  }

  static String defaultTypeLabel(String type) {
    return type == 'complaint' ? 'شكوى' : 'استفسار';
  }

  static const List<MapEntry<String, String>> categoryOptions = [
    MapEntry('general', 'استفسار عام'),
    MapEntry('account', 'الحساب والملف الشخصي'),
    MapEntry('subscription', 'العضوية والاشتراك'),
    MapEntry('technical', 'مشكلة تقنية'),
    MapEntry('behavior', 'شكوى سلوك أو محتوى'),
    MapEntry('suggestion', 'اقتراح وتطوير'),
  ];

  static String defaultCategoryLabel(String category) {
    for (final entry in categoryOptions) {
      if (entry.key == category) return entry.value;
    }
    return 'استفسار عام';
  }

  static String defaultStatusLabel(String status) {
    switch (status) {
      case 'in_progress':
        return 'قيد المراجعة';
      case 'answered':
        return 'تم الرد';
      case 'closed':
        return 'مغلق';
      case 'open':
      default:
        return 'جديد / مفتوح';
    }
  }

  static Color statusBgColor(String status) {
    switch (status) {
      case 'answered':
        return const Color(0xFFECFDF5);
      case 'in_progress':
        return const Color(0xFFEFF6FF);
      case 'closed':
        return const Color(0xFFF3F4F6);
      case 'open':
      default:
        return const Color(0xFFFEF9EE);
    }
  }

  static Color statusTextColor(String status) {
    switch (status) {
      case 'answered':
        return const Color(0xFF047857);
      case 'in_progress':
        return const Color(0xFF1D4ED8);
      case 'closed':
        return const Color(0xFF4B5563);
      case 'open':
      default:
        return const Color(0xFFB45309);
    }
  }
}

class PaginatedSupportTicketsResponse {
  final List<SupportTicketModel> tickets;
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;

  const PaginatedSupportTicketsResponse({
    required this.tickets,
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
  });

  bool get hasMorePages => currentPage < lastPage;

  factory PaginatedSupportTicketsResponse.fromJson(Map<String, dynamic> json) {
    final rawTickets = json['tickets'];
    final tickets = rawTickets is List
        ? rawTickets
            .whereType<Map>()
            .map((e) => SupportTicketModel.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : const <SupportTicketModel>[];

    final pagination = json['pagination'] is Map
        ? Map<String, dynamic>.from(json['pagination'] as Map)
        : const <String, dynamic>{};

    return PaginatedSupportTicketsResponse(
      tickets: tickets,
      currentPage: (pagination['current_page'] as num?)?.toInt() ?? 1,
      lastPage: (pagination['last_page'] as num?)?.toInt() ?? 1,
      perPage: (pagination['per_page'] as num?)?.toInt() ?? 20,
      total: (pagination['total'] as num?)?.toInt() ?? tickets.length,
    );
  }
}
