class AuthUserModel {
  final int id;
  final String email;
  final String accountStatus;
  final bool profileCompleted;
  final bool hasActiveSubscription;
  final String? suggestedFullName;

  const AuthUserModel({
    required this.id,
    required this.email,
    required this.accountStatus,
    required this.profileCompleted,
    required this.hasActiveSubscription,
    this.suggestedFullName,
  });

  AuthUserModel copyWith({
    int? id,
    String? email,
    String? accountStatus,
    bool? profileCompleted,
    bool? hasActiveSubscription,
    String? suggestedFullName,
  }) {
    return AuthUserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      accountStatus: accountStatus ?? this.accountStatus,
      profileCompleted: profileCompleted ?? this.profileCompleted,
      hasActiveSubscription:
          hasActiveSubscription ?? this.hasActiveSubscription,
      suggestedFullName: suggestedFullName ?? this.suggestedFullName,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'account_status': accountStatus,
      'profile_completed': profileCompleted,
      'has_active_subscription': hasActiveSubscription,
      if (suggestedFullName != null)
        'profile': {'full_name': suggestedFullName},
    };
  }

  factory AuthUserModel.fromJson(
    Map<String, dynamic> json, {
    String? googleSuggestedName,
  }) {
    final profile = json['profile'] as Map<String, dynamic>?;
    return AuthUserModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      email: (json['email'] as String?) ?? '',
      accountStatus: (json['account_status'] as String?) ?? 'active',
      profileCompleted: (json['profile_completed'] as bool?) ?? false,
      hasActiveSubscription:
          (json['has_active_subscription'] as bool?) ?? false,
      suggestedFullName:
          (profile?['full_name'] as String?) ?? googleSuggestedName,
    );
  }
}

class AuthSessionResult {
  final String token;
  final bool isNewUser;
  final String nextRoute; // 'home' | 'complete_profile'
  final AuthUserModel user;

  const AuthSessionResult({
    required this.token,
    required this.isNewUser,
    required this.nextRoute,
    required this.user,
  });
}

class SuspendedAccountException implements Exception {
  final String message;
  final String reason;

  const SuspendedAccountException({
    required this.message,
    required this.reason,
  });
}
