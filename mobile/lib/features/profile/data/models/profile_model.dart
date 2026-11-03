import '../../domain/profile_registration_draft.dart';

class ProfilePhotoMetadata {
  final int id;
  final String mimeType;
  final int fileSizeBytes;
  final String moderationStatus;
  final String streamUrl;

  const ProfilePhotoMetadata({
    required this.id,
    required this.mimeType,
    required this.fileSizeBytes,
    required this.moderationStatus,
    required this.streamUrl,
  });

  factory ProfilePhotoMetadata.fromJson(Map<String, dynamic> json) {
    return ProfilePhotoMetadata(
      id: (json['id'] as num).toInt(),
      mimeType: (json['mime_type'] as String?) ?? 'image/jpeg',
      fileSizeBytes: (json['file_size_bytes'] as num?)?.toInt() ?? 0,
      moderationStatus: (json['moderation_status'] as String?) ?? 'pending',
      streamUrl: (json['stream_url'] as String?) ?? '',
    );
  }
}

class ProfileModel {
  final int id;
  final int userId;
  final String fullName;
  final String gender;
  final DateTime dateOfBirth;
  final int ageYears;
  final String zodiacSign;
  final String maritalStatus;
  final bool previouslyMarried;
  final bool hasChildren;
  final int childrenCount;
  final String educationLevel;
  final String occupation;
  final int heightCm;
  final String smokingStatus;
  final String homeOwnership;
  final List<String> hobbies;
  final String nationality;
  final String countryOfResidence;
  final String region;
  final String? bio;
  final bool isVisible;
  final String photoPrivacy; // 'public' | 'subscribers_only' | 'accepted_matches_only'
  final String moderationStatus;
  final ProfilePhotoMetadata? primaryPhoto;

  const ProfileModel({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.gender,
    required this.dateOfBirth,
    required this.ageYears,
    required this.zodiacSign,
    required this.maritalStatus,
    required this.previouslyMarried,
    required this.hasChildren,
    required this.childrenCount,
    required this.educationLevel,
    required this.occupation,
    required this.heightCm,
    required this.smokingStatus,
    required this.homeOwnership,
    required this.hobbies,
    required this.nationality,
    required this.countryOfResidence,
    required this.region,
    this.bio,
    required this.isVisible,
    required this.photoPrivacy,
    required this.moderationStatus,
    this.primaryPhoto,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    final rawHobbies = json['hobbies'];
    final hobbiesList = rawHobbies is List
        ? rawHobbies.map((e) => e.toString()).toList()
        : <String>[];

    final dobString = (json['date_of_birth'] as String?) ?? '1992-06-15';
    final parsedDob = DateTime.tryParse(dobString) ?? DateTime(1992, 6, 15);

    final primaryPhotoMap = json['primary_photo'] as Map<String, dynamic>?;

    return ProfileModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      userId: (json['user_id'] as num?)?.toInt() ?? 0,
      fullName: (json['full_name'] as String?) ?? '',
      gender: (json['gender'] as String?) ?? 'female',
      dateOfBirth: parsedDob,
      ageYears: (json['age_years'] as num?)?.toInt() ?? 30,
      zodiacSign: (json['zodiac_sign'] as String?) ?? '',
      maritalStatus: (json['marital_status'] as String?) ?? 'single',
      previouslyMarried: (json['previously_married'] as bool?) ?? false,
      hasChildren: (json['has_children'] as bool?) ?? false,
      childrenCount: (json['children_count'] as num?)?.toInt() ?? 0,
      educationLevel: (json['education_level'] as String?) ?? 'bachelor',
      occupation: (json['occupation'] as String?) ?? '',
      heightCm: (json['height_cm'] as num?)?.toInt() ?? 168,
      smokingStatus: (json['smoking_status'] as String?) ?? 'non_smoker',
      homeOwnership: (json['home_ownership'] as String?) ?? 'owned',
      hobbies: hobbiesList,
      nationality: (json['nationality'] as String?) ?? '',
      countryOfResidence: (json['country_of_residence'] as String?) ?? '',
      region: (json['region'] as String?) ?? '',
      bio: json['bio'] as String?,
      isVisible: (json['is_visible'] as bool?) ?? true,
      photoPrivacy: (json['photo_privacy'] as String?) ?? 'public',
      moderationStatus: (json['moderation_status'] as String?) ?? 'pending',
      primaryPhoto: primaryPhotoMap != null
          ? ProfilePhotoMetadata.fromJson(primaryPhotoMap)
          : null,
    );
  }

  /// Converts aregistration draft into a ProfileModel (used when transitioning from registration).
  factory ProfileModel.fromRegistrationDraft(
    ProfileRegistrationDraft draft, {
    ProfilePhotoMetadata? primaryPhoto,
    String photoPrivacy = 'public',
  }) {
    final dob = draft.dateOfBirth ?? DateTime(1992, 6, 15);
    return ProfileModel(
      id: 1,
      userId: 1,
      fullName: draft.fullName,
      gender: draft.gender,
      dateOfBirth: dob,
      ageYears: draft.calculatedAgeYears ?? 30,
      zodiacSign: draft.calculatedZodiacSignAr,
      maritalStatus: draft.maritalStatus,
      previouslyMarried: draft.previouslyMarried,
      hasChildren: draft.hasChildren,
      childrenCount: draft.hasChildren ? draft.childrenCount : 0,
      educationLevel: draft.educationLevel,
      occupation: draft.occupation,
      heightCm: draft.heightCm,
      smokingStatus: draft.smokingStatus,
      homeOwnership: draft.homeOwnership,
      hobbies: List<String>.from(draft.hobbies),
      nationality: draft.nationality,
      countryOfResidence: draft.countryOfResidence,
      region: draft.region,
      bio: draft.bio.trim().isEmpty ? null : draft.bio.trim(),
      isVisible: draft.isVisible,
      photoPrivacy: photoPrivacy,
      moderationStatus: 'pending',
      primaryPhoto: primaryPhoto,
    );
  }

  ProfileRegistrationDraft toRegistrationDraft() {
    return ProfileRegistrationDraft(
      fullName: fullName,
      gender: gender,
      dateOfBirth: dateOfBirth,
      maritalStatus: maritalStatus,
      previouslyMarried: previouslyMarried,
      hasChildren: hasChildren,
      childrenCount: childrenCount,
      educationLevel: educationLevel,
      occupation: occupation,
      heightCm: heightCm,
      smokingStatus: smokingStatus,
      homeOwnership: homeOwnership,
      hobbies: List<String>.from(hobbies),
      nationality: nationality,
      countryOfResidence: countryOfResidence,
      region: region,
      bio: bio ?? '',
      isVisible: isVisible,
    );
  }

  String get genderLabelAr => gender == 'male' ? 'ذكر' : 'أنثى';

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
        'high_school' => 'ثانوية عامة أو ما يعادلها',
        'diploma' => 'دبلوم متوسط / فوق متوسط',
        'bachelor' => 'بكالوريوس / ليسانس',
        'master' => 'ماجستير',
        'doctorate' => 'دكتوراه',
        _ => 'مؤهل آخر',
      };

  String get smokingStatusLabelAr => switch (smokingStatus) {
        'smoker' => 'مدخن',
        'occasional' => 'مدخن أحياناً',
        _ => 'غير مدخن',
      };

  String get homeOwnershipLabelAr => switch (homeOwnership) {
        'owned' => 'تمليك خاص',
        'rented' => 'إيجار',
        'family_home' => 'سكن مع الأسرة',
        _ => 'غير محدد',
      };

  String get photoPrivacyLabelAr => switch (photoPrivacy) {
        'subscribers_only' => 'الأعضاء المشتركون فقط',
        'accepted_matches_only' => 'من تم قبول طلب التعارف معهم فقط',
        _ => 'جميع الأعضاء المسجلين',
      };

  String get moderationStatusLabelAr => switch (moderationStatus) {
        'approved' => 'معتمد ومنشور',
        'rejected' => 'يحتاج إلى تعديل',
        _ => 'قيد المراجعة',
      };

  ProfileModel copyWith({
    String? fullName,
    String? gender,
    DateTime? dateOfBirth,
    int? ageYears,
    String? zodiacSign,
    String? maritalStatus,
    bool? previouslyMarried,
    bool? hasChildren,
    int? childrenCount,
    String? educationLevel,
    String? occupation,
    int? heightCm,
    String? smokingStatus,
    String? homeOwnership,
    List<String>? hobbies,
    String? nationality,
    String? countryOfResidence,
    String? region,
    String? bio,
    bool? isVisible,
    String? photoPrivacy,
    String? moderationStatus,
    ProfilePhotoMetadata? primaryPhoto,
  }) {
    return ProfileModel(
      id: id,
      userId: userId,
      fullName: fullName ?? this.fullName,
      gender: gender ?? this.gender,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      ageYears: ageYears ?? this.ageYears,
      zodiacSign: zodiacSign ?? this.zodiacSign,
      maritalStatus: maritalStatus ?? this.maritalStatus,
      previouslyMarried: previouslyMarried ?? this.previouslyMarried,
      hasChildren: hasChildren ?? this.hasChildren,
      childrenCount: childrenCount ?? this.childrenCount,
      educationLevel: educationLevel ?? this.educationLevel,
      occupation: occupation ?? this.occupation,
      heightCm: heightCm ?? this.heightCm,
      smokingStatus: smokingStatus ?? this.smokingStatus,
      homeOwnership: homeOwnership ?? this.homeOwnership,
      hobbies: hobbies ?? this.hobbies,
      nationality: nationality ?? this.nationality,
      countryOfResidence: countryOfResidence ?? this.countryOfResidence,
      region: region ?? this.region,
      bio: bio ?? this.bio,
      isVisible: isVisible ?? this.isVisible,
      photoPrivacy: photoPrivacy ?? this.photoPrivacy,
      moderationStatus: moderationStatus ?? this.moderationStatus,
      primaryPhoto: primaryPhoto ?? this.primaryPhoto,
    );
  }
}

class ProfileResponseBundle {
  final bool profileCompleted;
  final int completionPercentage;
  final ProfileModel? profile;
  final bool isVisible;
  final String photoPrivacy;

  const ProfileResponseBundle({
    required this.profileCompleted,
    required this.completionPercentage,
    required this.profile,
    required this.isVisible,
    required this.photoPrivacy,
  });
}
