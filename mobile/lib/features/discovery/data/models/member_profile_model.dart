class MemberCardModel {
  final int userId;
  final String fullName;
  final String gender;
  final int ageYears;
  final String maritalStatus;
  final String educationLevel;
  final String occupation;
  final String smokingStatus;
  final String nationality;
  final String countryOfResidence;
  final String region;
  final String photoPrivacy;
  final bool photoAuthorized;
  final int? primaryPhotoId;
  final String? primaryPhotoUrl;
  final bool isFavorited;

  const MemberCardModel({
    required this.userId,
    required this.fullName,
    required this.gender,
    required this.ageYears,
    required this.maritalStatus,
    required this.educationLevel,
    required this.occupation,
    required this.smokingStatus,
    required this.nationality,
    required this.countryOfResidence,
    required this.region,
    required this.photoPrivacy,
    required this.photoAuthorized,
    this.primaryPhotoId,
    this.primaryPhotoUrl,
    required this.isFavorited,
  });

  factory MemberCardModel.fromJson(Map<String, dynamic> json) {
    return MemberCardModel(
      userId: (json['user_id'] as num).toInt(),
      fullName: (json['full_name'] as String?) ?? '',
      gender: (json['gender'] as String?) ?? 'female',
      ageYears: (json['age_years'] as num?)?.toInt() ?? 18,
      maritalStatus: (json['marital_status'] as String?) ?? 'single',
      educationLevel: (json['education_level'] as String?) ?? 'bachelor',
      occupation: (json['occupation'] as String?) ?? '',
      smokingStatus: (json['smoking_status'] as String?) ?? 'non_smoker',
      nationality: (json['nationality'] as String?) ?? '',
      countryOfResidence: (json['country_of_residence'] as String?) ?? '',
      region: (json['region'] as String?) ?? '',
      photoPrivacy: (json['photo_privacy'] as String?) ?? 'public',
      photoAuthorized: (json['photo_authorized'] as bool?) ?? false,
      primaryPhotoId: (json['primary_photo_id'] as num?)?.toInt(),
      primaryPhotoUrl: json['primary_photo_url'] as String?,
      isFavorited: (json['is_favorited'] as bool?) ?? false,
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

  String get educationLevelLabelAr => switch (educationLevel) {
        'high_school' => 'ثانوية عامة',
        'diploma' => 'دبلوم',
        'bachelor' => 'بكالوريوس',
        'master' => 'ماجستير',
        'doctorate' => 'دكتوراه',
        _ => 'مؤهل آخر',
      };

  String get smokingStatusLabelAr => switch (smokingStatus) {
        'smoker' => 'مدخن',
        'occasional' => 'مدخن أحياناً',
        _ => 'غير مدخن',
      };

  MemberCardModel copyWith({bool? isFavorited}) {
    return MemberCardModel(
      userId: userId,
      fullName: fullName,
      gender: gender,
      ageYears: ageYears,
      maritalStatus: maritalStatus,
      educationLevel: educationLevel,
      occupation: occupation,
      smokingStatus: smokingStatus,
      nationality: nationality,
      countryOfResidence: countryOfResidence,
      region: region,
      photoPrivacy: photoPrivacy,
      photoAuthorized: photoAuthorized,
      primaryPhotoId: primaryPhotoId,
      primaryPhotoUrl: primaryPhotoUrl,
      isFavorited: isFavorited ?? this.isFavorited,
    );
  }
}

class MemberProfileDetailModel extends MemberCardModel {
  final String zodiacSign;
  final bool previouslyMarried;
  final bool hasChildren;
  final int childrenCount;
  final int heightCm;
  final String homeOwnership;
  final List<String> hobbies;
  final String? bio;
  final bool viewerHasActiveSubscription;
  final bool viewerCanSendMatchRequests;
  final bool viewerCanSendMessages;
  final String matchmakingButtonState;
  final int? matchmakingRequestId;
  final String? matchmakingRequestStatus;
  final int? matchmakingConversationId;

  const MemberProfileDetailModel({
    required super.userId,
    required super.fullName,
    required super.gender,
    required super.ageYears,
    required super.maritalStatus,
    required super.educationLevel,
    required super.occupation,
    required super.smokingStatus,
    required super.nationality,
    required super.countryOfResidence,
    required super.region,
    required super.photoPrivacy,
    required super.photoAuthorized,
    super.primaryPhotoId,
    super.primaryPhotoUrl,
    required super.isFavorited,
    required this.zodiacSign,
    required this.previouslyMarried,
    required this.hasChildren,
    required this.childrenCount,
    required this.heightCm,
    required this.homeOwnership,
    required this.hobbies,
    this.bio,
    this.viewerHasActiveSubscription = false,
    this.viewerCanSendMatchRequests = false,
    this.viewerCanSendMessages = false,
    this.matchmakingButtonState = 'subscription_required',
    this.matchmakingRequestId,
    this.matchmakingRequestStatus,
    this.matchmakingConversationId,
  });

  factory MemberProfileDetailModel.fromJson(
    Map<String, dynamic> memberJson, {
    bool viewerHasActiveSubscription = false,
    bool viewerCanSendMatchRequests = false,
    bool viewerCanSendMessages = false,
    Map<String, dynamic>? matchmakingJson,
  }) {
    final rawHobbies = memberJson['hobbies'];
    final hobbiesList = rawHobbies is List
        ? rawHobbies.map((e) => e.toString()).toList()
        : <String>[];

    final defaultButtonState =
        (viewerCanSendMatchRequests || viewerHasActiveSubscription)
            ? 'available'
            : 'subscription_required';

    return MemberProfileDetailModel(
      userId: (memberJson['user_id'] as num).toInt(),
      fullName: (memberJson['full_name'] as String?) ?? '',
      gender: (memberJson['gender'] as String?) ?? 'female',
      ageYears: (memberJson['age_years'] as num?)?.toInt() ?? 18,
      maritalStatus: (memberJson['marital_status'] as String?) ?? 'single',
      educationLevel: (memberJson['education_level'] as String?) ?? 'bachelor',
      occupation: (memberJson['occupation'] as String?) ?? '',
      smokingStatus: (memberJson['smoking_status'] as String?) ?? 'non_smoker',
      nationality: (memberJson['nationality'] as String?) ?? '',
      countryOfResidence: (memberJson['country_of_residence'] as String?) ?? '',
      region: (memberJson['region'] as String?) ?? '',
      photoPrivacy: (memberJson['photo_privacy'] as String?) ?? 'public',
      photoAuthorized: (memberJson['photo_authorized'] as bool?) ?? false,
      primaryPhotoId: (memberJson['primary_photo_id'] as num?)?.toInt(),
      primaryPhotoUrl: memberJson['primary_photo_url'] as String?,
      isFavorited: (memberJson['is_favorited'] as bool?) ?? false,
      zodiacSign: (memberJson['zodiac_sign'] as String?) ?? '',
      previouslyMarried: (memberJson['previously_married'] as bool?) ?? false,
      hasChildren: (memberJson['has_children'] as bool?) ?? false,
      childrenCount: (memberJson['children_count'] as num?)?.toInt() ?? 0,
      heightCm: (memberJson['height_cm'] as num?)?.toInt() ?? 168,
      homeOwnership: (memberJson['home_ownership'] as String?) ?? 'not_specified',
      hobbies: hobbiesList,
      bio: memberJson['bio'] as String?,
      viewerHasActiveSubscription: viewerHasActiveSubscription,
      viewerCanSendMatchRequests:
          viewerCanSendMatchRequests || viewerHasActiveSubscription,
      viewerCanSendMessages:
          viewerCanSendMessages || viewerHasActiveSubscription,
      matchmakingButtonState:
          (matchmakingJson?['button_state'] as String?) ?? defaultButtonState,
      matchmakingRequestId: (matchmakingJson?['request_id'] as num?)?.toInt(),
      matchmakingRequestStatus: matchmakingJson?['request_status'] as String?,
      matchmakingConversationId:
          (matchmakingJson?['conversation_id'] as num?)?.toInt(),
    );
  }

  String get genderLabelAr => gender == 'male' ? 'ذكر' : 'أنثى';

  String get homeOwnershipLabelAr => switch (homeOwnership) {
        'owned' => 'تمليك خاص',
        'rented' => 'إيجار',
        'family_home' => 'سكن مع الأسرة',
        _ => 'غير محدد',
      };

  @override
  MemberProfileDetailModel copyWith({
    bool? isFavorited,
    String? matchmakingButtonState,
    int? matchmakingRequestId,
    String? matchmakingRequestStatus,
    int? matchmakingConversationId,
  }) {
    return MemberProfileDetailModel(
      userId: userId,
      fullName: fullName,
      gender: gender,
      ageYears: ageYears,
      maritalStatus: maritalStatus,
      educationLevel: educationLevel,
      occupation: occupation,
      smokingStatus: smokingStatus,
      nationality: nationality,
      countryOfResidence: countryOfResidence,
      region: region,
      photoPrivacy: photoPrivacy,
      photoAuthorized: photoAuthorized,
      primaryPhotoId: primaryPhotoId,
      primaryPhotoUrl: primaryPhotoUrl,
      isFavorited: isFavorited ?? this.isFavorited,
      zodiacSign: zodiacSign,
      previouslyMarried: previouslyMarried,
      hasChildren: hasChildren,
      childrenCount: childrenCount,
      heightCm: heightCm,
      homeOwnership: homeOwnership,
      hobbies: hobbies,
      bio: bio,
      viewerHasActiveSubscription: viewerHasActiveSubscription,
      viewerCanSendMatchRequests: viewerCanSendMatchRequests,
      viewerCanSendMessages: viewerCanSendMessages,
      matchmakingButtonState:
          matchmakingButtonState ?? this.matchmakingButtonState,
      matchmakingRequestId: matchmakingRequestId ?? this.matchmakingRequestId,
      matchmakingRequestStatus:
          matchmakingRequestStatus ?? this.matchmakingRequestStatus,
      matchmakingConversationId:
          matchmakingConversationId ?? this.matchmakingConversationId,
    );
  }
}

class PaginatedMembersResponse {
  final List<MemberCardModel> members;
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;
  final bool hasMorePages;

  const PaginatedMembersResponse({
    required this.members,
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
    required this.hasMorePages,
  });

  factory PaginatedMembersResponse.fromJson(Map<String, dynamic> data) {
    final rawMembers = data['members'] as List<dynamic>? ?? const [];
    final pagination = data['pagination'] as Map<String, dynamic>? ?? const {};

    return PaginatedMembersResponse(
      members: rawMembers
          .whereType<Map<String, dynamic>>()
          .map(MemberCardModel.fromJson)
          .toList(),
      currentPage: (pagination['current_page'] as num?)?.toInt() ?? 1,
      lastPage: (pagination['last_page'] as num?)?.toInt() ?? 1,
      perPage: (pagination['per_page'] as num?)?.toInt() ?? 20,
      total: (pagination['total'] as num?)?.toInt() ?? 0,
      hasMorePages: (pagination['has_more_pages'] as bool?) ?? false,
    );
  }
}
