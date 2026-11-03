class SearchFilterChipItem {
  final String key;
  final String labelAr;

  const SearchFilterChipItem({
    required this.key,
    required this.labelAr,
  });
}

class SearchPreferencesModel {
  final String? gender; // 'male' | 'female' | null
  final int minAge;
  final int maxAge;
  final List<String> maritalStatuses; // ['single', 'divorced', 'widowed']
  final String? educationLevel; // 'bachelor', 'master', etc.
  final String? smokingStatus; // 'non_smoker', 'smoker', 'occasional', 'all', or null
  final String? occupation;
  final String? nationality;
  final String? countryOfResidence;
  final String? region;
  final String sort; // 'newest' | 'age_asc' | 'age_desc'

  const SearchPreferencesModel({
    this.gender,
    this.minAge = 18,
    this.maxAge = 60,
    this.maritalStatuses = const [],
    this.educationLevel,
    this.smokingStatus,
    this.occupation,
    this.nationality,
    this.countryOfResidence,
    this.region,
    this.sort = 'newest',
  });

  factory SearchPreferencesModel.fromJson(Map<String, dynamic> json) {
    final rawMarital = json['marital_statuses'];
    final maritalList = rawMarital is List
        ? rawMarital.map((e) => e.toString()).toList()
        : <String>[];

    final rawMinAge = (json['min_age'] as num?)?.toInt() ?? 18;
    final rawMaxAge = (json['max_age'] as num?)?.toInt() ?? 60;

    return SearchPreferencesModel(
      gender: (json['preferred_gender'] ?? json['gender']) as String?,
      minAge: rawMinAge < 18 ? 18 : rawMinAge,
      maxAge: rawMaxAge < 18 ? 60 : rawMaxAge,
      maritalStatuses: maritalList,
      educationLevel: json['education_level'] as String?,
      smokingStatus: json['smoking_status'] as String?,
      occupation: json['occupation'] as String?,
      nationality: json['nationality'] as String?,
      countryOfResidence: json['country_of_residence'] as String?,
      region: json['region'] as String?,
      sort: (json['sort'] as String?) ?? 'newest',
    );
  }

  /// Validates search filter parameters before submitting to PostgreSQL backend.
  String? validate() {
    if (minAge < 18) {
      return 'الحد الأدنى للعمر يجب ألا يقل عن 18 سنة.';
    }
    if (maxAge < 18) {
      return 'الحد الأقصى للعمر يجب ألا يقل عن 18 سنة.';
    }
    if (minAge > maxAge) {
      return 'الحد الأدنى للعمر يجب أن يكون أقل من أو يساوي الحد الأقصى للعمر.';
    }
    return null;
  }

  Map<String, dynamic> toQueryParameters({
    required int page,
    int perPage = 20,
    bool savePreferences = false,
  }) {
    final params = <String, dynamic>{
      'min_age': minAge,
      'max_age': maxAge,
      'sort': sort,
      'page': page,
      'per_page': perPage,
      if (savePreferences) 'save_preferences': 1,
    };

    if (gender != null && gender!.isNotEmpty) {
      params['gender'] = gender;
    }
    if (maritalStatuses.isNotEmpty) {
      params['marital_statuses'] = maritalStatuses;
    }
    if (educationLevel != null && educationLevel!.isNotEmpty) {
      params['education_level'] = educationLevel;
    }
    if (smokingStatus != null &&
        smokingStatus!.isNotEmpty &&
        smokingStatus != 'all') {
      params['smoking_status'] = smokingStatus;
    }
    if (occupation != null && occupation!.trim().isNotEmpty) {
      params['occupation'] = occupation!.trim();
    }
    if (nationality != null && nationality!.trim().isNotEmpty) {
      params['nationality'] = nationality!.trim();
    }
    if (countryOfResidence != null && countryOfResidence!.trim().isNotEmpty) {
      params['country_of_residence'] = countryOfResidence!.trim();
    }
    if (region != null && region!.trim().isNotEmpty) {
      params['region'] = region!.trim();
    }

    return params;
  }

  Map<String, dynamic> toPreferenceBody() {
    return {
      'preferred_gender': gender,
      'min_age': minAge,
      'max_age': maxAge,
      'marital_statuses': maritalStatuses,
      'education_level': educationLevel,
      'smoking_status': smokingStatus == 'all' ? null : smokingStatus,
      'occupation':
          (occupation != null && occupation!.trim().isNotEmpty) ? occupation!.trim() : null,
      'nationality':
          (nationality != null && nationality!.trim().isNotEmpty) ? nationality!.trim() : null,
      'country_of_residence': (countryOfResidence != null &&
              countryOfResidence!.trim().isNotEmpty)
          ? countryOfResidence!.trim()
          : null,
      'region': (region != null && region!.trim().isNotEmpty) ? region!.trim() : null,
    };
  }

  /// Generates active removable chips for Screen 09 (Search Results)
  List<SearchFilterChipItem> get activeFilterChips {
    final chips = <SearchFilterChipItem>[];

    if (gender != null && gender!.isNotEmpty) {
      chips.add(SearchFilterChipItem(
        key: 'gender',
        labelAr: gender == 'male' ? 'ذكر' : 'أنثى',
      ));
    }

    chips.add(SearchFilterChipItem(
      key: 'age_range',
      labelAr: '$minAge–$maxAge سنة',
    ));

    if (maritalStatuses.isNotEmpty) {
      final labels = maritalStatuses.map((s) {
        if (gender == 'female') {
          return switch (s) {
            'divorced' => 'مطلقة',
            'widowed' => 'أرملة',
            _ => 'عزباء',
          };
        }
        return switch (s) {
          'divorced' => 'مطلق',
          'widowed' => 'أرمل',
          _ => 'أعزب',
        };
      }).join('، ');
      chips.add(SearchFilterChipItem(
        key: 'marital_statuses',
        labelAr: labels,
      ));
    }

    if (educationLevel != null && educationLevel!.isNotEmpty) {
      final eduLabel = switch (educationLevel) {
        'high_school' => 'ثانوية عامة',
        'diploma' => 'دبلوم',
        'bachelor' => 'بكالوريوس',
        'master' => 'ماجستير',
        'doctorate' => 'دكتوراه',
        _ => 'مؤهل آخر',
      };
      chips.add(SearchFilterChipItem(
        key: 'education_level',
        labelAr: eduLabel,
      ));
    }

    if (smokingStatus != null &&
        smokingStatus!.isNotEmpty &&
        smokingStatus != 'all') {
      final smokeLabel = switch (smokingStatus) {
        'smoker' => 'مدخن',
        'occasional' => 'مدخن أحياناً',
        _ => 'غير مدخن',
      };
      chips.add(SearchFilterChipItem(
        key: 'smoking_status',
        labelAr: smokeLabel,
      ));
    }

    if (occupation != null && occupation!.trim().isNotEmpty) {
      chips.add(SearchFilterChipItem(
        key: 'occupation',
        labelAr: 'المهنة: ${occupation!.trim()}',
      ));
    }

    if (nationality != null && nationality!.trim().isNotEmpty) {
      chips.add(SearchFilterChipItem(
        key: 'nationality',
        labelAr: 'الجنسية: ${nationality!.trim()}',
      ));
    }

    if (countryOfResidence != null && countryOfResidence!.trim().isNotEmpty) {
      chips.add(SearchFilterChipItem(
        key: 'country_of_residence',
        labelAr: 'الإقامة: ${countryOfResidence!.trim()}',
      ));
    }

    if (region != null && region!.trim().isNotEmpty) {
      chips.add(SearchFilterChipItem(
        key: 'region',
        labelAr: 'المنطقة: ${region!.trim()}',
      ));
    }

    return chips;
  }

  SearchPreferencesModel removeFilterByKey(String key) {
    return switch (key) {
      'gender' => copyWith(clearGender: true),
      'age_range' => copyWith(minAge: 18, maxAge: 65),
      'marital_statuses' => copyWith(maritalStatuses: const []),
      'education_level' => copyWith(clearEducation: true),
      'smoking_status' => copyWith(clearSmoking: true),
      'occupation' => copyWith(clearOccupation: true),
      'nationality' => copyWith(clearNationality: true),
      'country_of_residence' => copyWith(clearCountry: true),
      'region' => copyWith(clearRegion: true),
      _ => this,
    };
  }

  SearchPreferencesModel copyWith({
    String? gender,
    bool clearGender = false,
    int? minAge,
    int? maxAge,
    List<String>? maritalStatuses,
    String? educationLevel,
    bool clearEducation = false,
    String? smokingStatus,
    bool clearSmoking = false,
    String? occupation,
    bool clearOccupation = false,
    String? nationality,
    bool clearNationality = false,
    String? countryOfResidence,
    bool clearCountry = false,
    String? region,
    bool clearRegion = false,
    String? sort,
  }) {
    return SearchPreferencesModel(
      gender: clearGender ? null : (gender ?? this.gender),
      minAge: minAge ?? this.minAge,
      maxAge: maxAge ?? this.maxAge,
      maritalStatuses: maritalStatuses ?? this.maritalStatuses,
      educationLevel:
          clearEducation ? null : (educationLevel ?? this.educationLevel),
      smokingStatus:
          clearSmoking ? null : (smokingStatus ?? this.smokingStatus),
      occupation: clearOccupation ? null : (occupation ?? this.occupation),
      nationality: clearNationality ? null : (nationality ?? this.nationality),
      countryOfResidence:
          clearCountry ? null : (countryOfResidence ?? this.countryOfResidence),
      region: clearRegion ? null : (region ?? this.region),
      sort: sort ?? this.sort,
    );
  }
}
