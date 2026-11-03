class ProfileRegistrationDraft {
  final String fullName;
  final String? photoPath;
  final String gender; // 'female' | 'male'
  final DateTime? dateOfBirth;
  final String maritalStatus; // 'single' | 'divorced' | 'widowed'
  final bool previouslyMarried;
  final bool hasChildren;
  final int childrenCount;
  final String educationLevel; // 'bachelor' | 'master' | 'doctorate' | 'diploma' | 'high_school' | 'other'
  final String occupation;
  final int heightCm;
  final String smokingStatus; // 'non_smoker' | 'smoker' | 'occasional'
  final String homeOwnership; // 'owned' | 'rented' | 'family_home' | 'not_specified'
  final List<String> hobbies;
  final String nationality;
  final String countryOfResidence;
  final String region;
  final String bio;
  final bool isVisible;

  const ProfileRegistrationDraft({
    this.fullName = '',
    this.photoPath,
    this.gender = 'female',
    this.dateOfBirth,
    this.maritalStatus = 'single',
    this.previouslyMarried = false,
    this.hasChildren = false,
    this.childrenCount = 0,
    this.educationLevel = 'bachelor',
    this.occupation = '',
    this.heightCm = 168,
    this.smokingStatus = 'non_smoker',
    this.homeOwnership = 'owned',
    this.hobbies = const ['القراءة', 'السفر'],
    this.nationality = 'مصرية',
    this.countryOfResidence = 'مصر',
    this.region = 'القاهرة',
    this.bio = '',
    this.isVisible = true,
  });

  /// Calculates exact age in years from dateOfBirth.
  int? get calculatedAgeYears {
    final dob = dateOfBirth;
    if (dob == null) return null;
    final today = DateTime.now();
    int age = today.year - dob.year;
    if (today.month < dob.month ||
        (today.month == dob.month && today.day < dob.day)) {
      age--;
    }
    return age;
  }

  /// Automatically calculates the Arabic Zodiac Sign (البرج الفلكي) from dateOfBirth.
  String get calculatedZodiacSignAr {
    final dob = dateOfBirth;
    if (dob == null) return 'يُحسب تلقائياً من تاريخ الميلاد';
    final month = dob.month;
    final day = dob.day;

    if ((month == 3 && day >= 21) || (month == 4 && day <= 19)) return 'الحمل';
    if ((month == 4 && day >= 20) || (month == 5 && day <= 20)) return 'الثور';
    if ((month == 5 && day >= 21) || (month == 6 && day <= 20)) return 'الجوزاء';
    if ((month == 6 && day >= 21) || (month == 7 && day <= 22)) return 'السرطان';
    if ((month == 7 && day >= 23) || (month == 8 && day <= 22)) return 'الأسد';
    if ((month == 8 && day >= 23) || (month == 9 && day <= 22)) return 'العذراء';
    if ((month == 9 && day >= 23) || (month == 10 && day <= 22)) return 'الميزان';
    if ((month == 10 && day >= 23) || (month == 11 && day <= 21)) return 'العقرب';
    if ((month == 11 && day >= 22) || (month == 12 && day <= 21)) return 'القوس';
    if ((month == 12 && day >= 22) || (month == 1 && day <= 19)) return 'الجدي';
    if ((month == 1 && day >= 20) || (month == 2 && day <= 18)) return 'الدلو';
    return 'الحوت';
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
        _ => 'غير محدد حالياً',
      };

  Map<String, dynamic> toApiPayload() {
    final dob = dateOfBirth ?? DateTime(1992, 6, 15);
    final formattedDob =
        '${dob.year.toString().padLeft(4, '0')}-${dob.month.toString().padLeft(2, '0')}-${dob.day.toString().padLeft(2, '0')}';

    return {
      'full_name': fullName.trim(),
      'gender': gender,
      'date_of_birth': formattedDob,
      'marital_status': maritalStatus,
      'previously_married': previouslyMarried,
      'has_children': hasChildren,
      'children_count': hasChildren ? childrenCount : 0,
      'education_level': educationLevel,
      'occupation': occupation.trim(),
      'height_cm': heightCm,
      'zodiac_sign': calculatedZodiacSignAr,
      'smoking_status': smokingStatus,
      'home_ownership': homeOwnership,
      'hobbies': hobbies,
      'nationality': nationality.trim(),
      'country_of_residence': countryOfResidence.trim(),
      'region': region.trim(),
      'bio': bio.trim().isEmpty ? null : bio.trim(),
      'is_visible': isVisible,
    };
  }

  ProfileRegistrationDraft copyWith({
    String? fullName,
    String? photoPath,
    String? gender,
    DateTime? dateOfBirth,
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
  }) {
    return ProfileRegistrationDraft(
      fullName: fullName ?? this.fullName,
      photoPath: photoPath ?? this.photoPath,
      gender: gender ?? this.gender,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
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
    );
  }
}
