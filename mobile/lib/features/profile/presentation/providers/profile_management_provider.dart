import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/profile_model.dart';
import '../../data/repositories/profile_repository.dart';
import '../../domain/profile_registration_draft.dart';
import 'profile_registration_provider.dart';

class ProfileManagementState {
  final bool isLoading;
  final bool isSaving;
  final bool isUploadingPhoto;
  final double uploadProgress;
  final int completionPercentage;
  final ProfileModel? profile;
  final Uint8List? cachedPhotoBytes;
  final String? errorMessage;
  final String? successMessage;

  const ProfileManagementState({
    this.isLoading = false,
    this.isSaving = false,
    this.isUploadingPhoto = false,
    this.uploadProgress = 0.0,
    this.completionPercentage = 0,
    this.profile,
    this.cachedPhotoBytes,
    this.errorMessage,
    this.successMessage,
  });

  ProfileManagementState copyWith({
    bool? isLoading,
    bool? isSaving,
    bool? isUploadingPhoto,
    double? uploadProgress,
    int? completionPercentage,
    ProfileModel? profile,
    Uint8List? cachedPhotoBytes,
    String? errorMessage,
    String? successMessage,
    bool clearMessages = false,
  }) {
    return ProfileManagementState(
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      isUploadingPhoto: isUploadingPhoto ?? this.isUploadingPhoto,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      completionPercentage: completionPercentage ?? this.completionPercentage,
      profile: profile ?? this.profile,
      cachedPhotoBytes: cachedPhotoBytes ?? this.cachedPhotoBytes,
      errorMessage:
          clearMessages ? null : (errorMessage ?? this.errorMessage),
      successMessage:
          clearMessages ? null : (successMessage ?? this.successMessage),
    );
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ProfileRepository(apiClient);
});

class ProfileManagementNotifier extends StateNotifier<ProfileManagementState> {
  final ProfileRepository _repository;
  final Ref _ref;

  ProfileManagementNotifier(this._repository, this._ref)
      : super(const ProfileManagementState());

  /// Loads the authenticated user's profile from GET /api/v1/profile.
  /// Never generates fake profile data: if the user has not completed a profile
  /// on the server or in the current registration draft, profile remains null (Empty State).
  Future<void> loadOwnProfile() async {
    state = state.copyWith(isLoading: true, clearMessages: true);
    try {
      final bundle = await _repository.fetchOwnProfile();
      Uint8List? photoBytes = state.cachedPhotoBytes;

      if (bundle.profile?.primaryPhoto != null) {
        try {
          photoBytes = await _repository.fetchProtectedPhotoBytes(
            bundle.profile!.primaryPhoto!.id,
          );
        } catch (_) {
          // Keep existing cached bytes if photo stream is temporarily unreachable
        }
      }

      state = state.copyWith(
        isLoading: false,
        profile: bundle.profile,
        completionPercentage: bundle.completionPercentage,
        cachedPhotoBytes: photoBytes,
      );
    } catch (e) {
      // If user just completed registration in this session, preserve their real entered draft
      final regDraft = _ref.read(profileRegistrationProvider).draft;
      if (state.profile == null && regDraft.fullName.trim().isNotEmpty) {
        final localProfile = ProfileModel.fromRegistrationDraft(regDraft);
        state = state.copyWith(
          isLoading: false,
          profile: localProfile,
          completionPercentage: _computeLocalCompletion(localProfile),
        );
        return;
      }

      if (state.profile != null) {
        state = state.copyWith(isLoading: false);
        return;
      }

      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  /// Syncs a newly published registration draft directly into ProfileManagementState
  void syncFromRegistrationDraft(ProfileRegistrationDraft draft) {
    if (draft.fullName.trim().isEmpty) return;
    final model = ProfileModel.fromRegistrationDraft(draft);
    state = state.copyWith(
      profile: model,
      completionPercentage: _computeLocalCompletion(model),
      clearMessages: true,
    );
  }

  /// Validates and submits profile edits to PATCH /api/v1/profile
  Future<bool> saveEditedProfile(ProfileRegistrationDraft updatedDraft) async {
    final validationError = validateProfileDraft(updatedDraft);
    if (validationError != null) {
      state = state.copyWith(
        errorMessage: validationError,
        successMessage: null,
      );
      return false;
    }

    state = state.copyWith(isSaving: true, clearMessages: true);
    try {
      final bundle = await _repository.updateProfile(
        updatedDraft,
        photoPrivacy: state.profile?.photoPrivacy ?? 'public',
      );
      state = state.copyWith(
        isSaving: false,
        profile: bundle.profile,
        completionPercentage: bundle.completionPercentage,
        successMessage: 'تم حفظ التعديلات على ملفك الشخصي بنجاح.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  /// Uploads a compressed profile photo to POST /api/v1/profile/photo
  Future<bool> uploadProfilePhoto({
    required Uint8List compressedBytes,
    required String filename,
    String mimeType = 'image/jpeg',
  }) async {
    if (compressedBytes.lengthInBytes > 2 * 1024 * 1024) {
      state = state.copyWith(
        errorMessage: 'حجم الصورة يتجاوز الحد الأقصى المسموح به (2 ميجابايت).',
      );
      return false;
    }

    state = state.copyWith(
      isUploadingPhoto: true,
      uploadProgress: 0.05,
      clearMessages: true,
    );

    try {
      final metadata = await _repository.uploadProfilePhotoBytes(
        imageBytes: compressedBytes,
        filename: filename,
        mimeType: mimeType,
        onProgress: (progress) {
          state = state.copyWith(uploadProgress: progress);
        },
      );

      final updatedProfile = state.profile?.copyWith(primaryPhoto: metadata);

      state = state.copyWith(
        isUploadingPhoto: false,
        uploadProgress: 1.0,
        profile: updatedProfile,
        cachedPhotoBytes: compressedBytes,
        completionPercentage: updatedProfile != null
            ? _computeLocalCompletion(updatedProfile)
            : state.completionPercentage,
        successMessage: 'تم تحديث الصورة الشخصية بنجاح.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isUploadingPhoto: false,
        uploadProgress: 0.0,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  /// Updates profile visibility and photo privacy via PATCH /api/v1/profile/privacy
  Future<bool> updatePrivacySettings({
    required bool isVisible,
    required String photoPrivacy,
  }) async {
    state = state.copyWith(isSaving: true, clearMessages: true);
    try {
      final updated = await _repository.updatePrivacySettings(
        isVisible: isVisible,
        photoPrivacy: photoPrivacy,
      );

      final currentProfile = state.profile;
      state = state.copyWith(
        isSaving: false,
        profile: currentProfile?.copyWith(
          isVisible: updated.isVisible,
          photoPrivacy: updated.photoPrivacy,
        ),
        successMessage: 'تم تحديث إعدادات الخصوصية فوراً.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  void clearFeedbackMessages() {
    state = state.copyWith(clearMessages: true);
  }

  /// Client-side mirror of backend validation rules (18+ age gate, marital status consistency).
  static String? validateProfileDraft(ProfileRegistrationDraft draft) {
    if (draft.fullName.trim().length < 3) {
      return 'يرجى إدخال الاسم الكامل (3 أحرف على الأقل).';
    }

    final age = draft.calculatedAgeYears;
    if (age == null) {
      return 'يرجى تحديد تاريخ الميلاد.';
    }
    if (age < 18) {
      return 'تطبيق نَصِيبُكَ مخصص للبالغين من عمر 18 عاماً فأكثر فقط.';
    }

    if (draft.maritalStatus == 'single' && draft.previouslyMarried) {
      return 'لا يمكن اختيار "سبق الزواج" عندما تكون الحالة الاجتماعية (${draft.maritalStatusLabelAr}).';
    }

    if (draft.maritalStatus == 'single' && draft.hasChildren) {
      return 'لا يتوافق وجود أطفال مع الحالة الاجتماعية (${draft.maritalStatusLabelAr}).';
    }

    if ((draft.maritalStatus == 'divorced' ||
            draft.maritalStatus == 'widowed') &&
        !draft.previouslyMarried) {
      return 'الحالة الاجتماعية (${draft.maritalStatusLabelAr}) تتطلب أن تكون الإجابة على "هل سبق لك الزواج؟" هي نعم.';
    }

    if (draft.occupation.trim().length < 2) {
      return 'يرجى إدخال المهنة أو مجال العمل.';
    }

    if (draft.heightCm < 120 || draft.heightCm > 230) {
      return 'يرجى تحديد طول صحيح بين 120 و 230 سم.';
    }

    if (draft.hobbies.isEmpty) {
      return 'يرجى اختيار هواية واحدة على الأقل.';
    }

    if (draft.nationality.trim().length < 2 ||
        draft.countryOfResidence.trim().length < 2 ||
        draft.region.trim().length < 2) {
      return 'يرجى استكمال بيانات الجنسية وبلد الإقامة والمحافظة/المنطقة.';
    }

    return null;
  }

  int _computeLocalCompletion(ProfileModel profile) {
    int score = 8; // Core required fields present
    if (profile.bio != null && profile.bio!.trim().isNotEmpty) score++;
    if (profile.primaryPhoto != null || state.cachedPhotoBytes != null) score++;
    return ((score / 10) * 100).round();
  }
}

final profileManagementProvider = StateNotifierProvider<
    ProfileManagementNotifier, ProfileManagementState>((ref) {
  final repo = ref.watch(profileRepositoryProvider);
  return ProfileManagementNotifier(repo, ref);
});
