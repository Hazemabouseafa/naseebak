class MatchmakingMemberSummary {
  final int userId;
  final String fullName;
  final String gender;
  final int ageYears;
  final String maritalStatus;
  final String region;
  final String countryOfResidence;
  final String photoPrivacy;
  final bool photoAuthorized;
  final int? primaryPhotoId;
  final String? primaryPhotoUrl;

  const MatchmakingMemberSummary({
    required this.userId,
    required this.fullName,
    required this.gender,
    required this.ageYears,
    required this.maritalStatus,
    required this.region,
    required this.countryOfResidence,
    required this.photoPrivacy,
    required this.photoAuthorized,
    this.primaryPhotoId,
    this.primaryPhotoUrl,
  });

  factory MatchmakingMemberSummary.fromJson(Map<String, dynamic> json) {
    return MatchmakingMemberSummary(
      userId: (json['user_id'] as num?)?.toInt() ?? 0,
      fullName: (json['full_name'] as String?) ?? 'عضو نصيبك',
      gender: (json['gender'] as String?) ?? 'female',
      ageYears: (json['age_years'] as num?)?.toInt() ?? 18,
      maritalStatus: (json['marital_status'] as String?) ?? 'single',
      region: (json['region'] as String?) ?? '',
      countryOfResidence: (json['country_of_residence'] as String?) ?? '',
      photoPrivacy: (json['photo_privacy'] as String?) ?? 'public',
      photoAuthorized: (json['photo_authorized'] as bool?) ?? false,
      primaryPhotoId: (json['primary_photo_id'] as num?)?.toInt(),
      primaryPhotoUrl: json['primary_photo_url'] as String?,
    );
  }

  String get maritalStatusLabelAr {
    if (gender == 'male') {
      return switch (maritalStatus) {
        'divorced' => 'مطلق',
        'widowed' => 'أرمل',
        _ => 'أعزب',
      };
    }
    return switch (maritalStatus) {
      'divorced' => 'مطلقة',
      'widowed' => 'أرملة',
      _ => 'عزباء',
    };
  }
}

class MatchmakingRequestItemModel {
  final int id;
  final String direction; // incoming, sent, accepted
  final int senderId;
  final int recipientId;
  final String status; // pending, accepted, rejected, cancelled
  final String statusLabelAr;
  final bool canAccept;
  final bool canReject;
  final bool canCancel;
  final int? conversationId;
  final String? createdAt;
  final String? respondedAt;
  final MatchmakingMemberSummary member;

  const MatchmakingRequestItemModel({
    required this.id,
    required this.direction,
    required this.senderId,
    required this.recipientId,
    required this.status,
    required this.statusLabelAr,
    required this.canAccept,
    required this.canReject,
    required this.canCancel,
    this.conversationId,
    this.createdAt,
    this.respondedAt,
    required this.member,
  });

  factory MatchmakingRequestItemModel.fromJson(Map<String, dynamic> json) {
    final rawMember =
        json['member'] as Map<String, dynamic>? ?? const <String, dynamic>{};

    return MatchmakingRequestItemModel(
      id: (json['id'] as num).toInt(),
      direction: (json['direction'] as String?) ?? 'incoming',
      senderId: (json['sender_id'] as num?)?.toInt() ?? 0,
      recipientId: (json['recipient_id'] as num?)?.toInt() ?? 0,
      status: (json['status'] as String?) ?? 'pending',
      statusLabelAr: (json['status_label_ar'] as String?) ?? 'قيد الانتظار',
      canAccept: (json['can_accept'] as bool?) ?? false,
      canReject: (json['can_reject'] as bool?) ?? false,
      canCancel: (json['can_cancel'] as bool?) ?? false,
      conversationId: (json['conversation_id'] as num?)?.toInt(),
      createdAt: json['created_at'] as String?,
      respondedAt: json['responded_at'] as String?,
      member: MatchmakingMemberSummary.fromJson(rawMember),
    );
  }
}

class MatchmakingRequestsBundle {
  final List<MatchmakingRequestItemModel> incoming;
  final List<MatchmakingRequestItemModel> sent;
  final List<MatchmakingRequestItemModel> accepted;

  const MatchmakingRequestsBundle({
    this.incoming = const [],
    this.sent = const [],
    this.accepted = const [],
  });

  factory MatchmakingRequestsBundle.fromJson(Map<String, dynamic> data) {
    List<MatchmakingRequestItemModel> parseList(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(MatchmakingRequestItemModel.fromJson)
          .toList();
    }

    return MatchmakingRequestsBundle(
      incoming: parseList(data['incoming']),
      sent: parseList(data['sent']),
      accepted: parseList(data['accepted']),
    );
  }
}

class MatchmakingCreateResult {
  final bool isSuccess;
  final bool isSubscriptionRequired;
  final String? errorCode;
  final String message;
  final MatchmakingRequestItemModel? request;

  const MatchmakingCreateResult({
    required this.isSuccess,
    this.isSubscriptionRequired = false,
    this.errorCode,
    required this.message,
    this.request,
  });
}
