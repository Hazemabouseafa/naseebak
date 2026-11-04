class BlockedMemberModel {
  final int id;
  final int blockedUserId;
  final String fullName;
  final String gender;
  final int ageYears;
  final String region;
  final String countryOfResidence;
  final String reason;
  final DateTime? blockedAt;
  final bool unblockAllowed;

  const BlockedMemberModel({
    required this.id,
    required this.blockedUserId,
    required this.fullName,
    required this.gender,
    required this.ageYears,
    required this.region,
    required this.countryOfResidence,
    required this.reason,
    this.blockedAt,
    this.unblockAllowed = true,
  });

  factory BlockedMemberModel.fromJson(Map<String, dynamic> json) {
    return BlockedMemberModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      blockedUserId: (json['blocked_user_id'] as num?)?.toInt() ?? 0,
      fullName: (json['full_name'] as String?)?.trim().isNotEmpty == true
          ? (json['full_name'] as String)
          : 'عضو نصيبك',
      gender: (json['gender'] as String?) ?? 'female',
      ageYears: (json['age_years'] as num?)?.toInt() ?? 18,
      region: (json['region'] as String?) ?? '',
      countryOfResidence: (json['country_of_residence'] as String?) ?? '',
      reason: (json['reason'] as String?) ?? 'تم الحظر بواسطة المستخدم',
      blockedAt: json['blocked_at'] != null
          ? DateTime.tryParse(json['blocked_at'].toString())
          : null,
      unblockAllowed: (json['unblock_allowed'] as bool?) ?? true,
    );
  }
}
