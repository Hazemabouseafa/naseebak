import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/profile_registration_draft.dart';
import 'profile_management_provider.dart';

class ProfileRegistrationState {
  /// Step 1: 03 Basic Profile Info
  /// Step 2: 04 Family, Education & Work
  /// Step 3: 05 Additional Details & Biography
  /// Step 4: 06 Profile Preview & Publish
  final int currentStep;
  final ProfileRegistrationDraft draft;
  final String? validationError;
  final bool isSubmitting;

  const ProfileRegistrationState({
    this.currentStep = 1,
    this.draft = const ProfileRegistrationDraft(),
    this.validationError,
    this.isSubmitting = false,
  });

  ProfileRegistrationState copyWith({
    int? currentStep,
    ProfileRegistrationDraft? draft,
    String? validationError,
    bool clearError = false,
    bool? isSubmitting,
  }) {
    return ProfileRegistrationState(
      currentStep: currentStep ?? this.currentStep,
      draft: draft ?? this.draft,
      validationError:
          clearError ? null : (validationError ?? this.validationError),
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}

class ProfileRegistrationNotifier
    extends StateNotifier<ProfileRegistrationState> {
  final ApiClient _apiClient;
  final Ref _ref;

  ProfileRegistrationNotifier(this._apiClient, this._ref)
      : super(
          ProfileRegistrationState(
            draft: ProfileRegistrationDraft(
              dateOfBirth: DateTime(1992, 6, 15),
            ),
          ),
        );

  void updateDraft(ProfileRegistrationDraft updated) {
    state = state.copyWith(draft: updated, clearError: true);
  }

  /// Validates Step 1 (Screen 03: Basic Profile Information)
  /// Enforces full name and strict >= 18 age requirement.
  bool validateAndAdvanceFromStep1() {
    final draft = state.draft;
    if (draft.fullName.trim().length < 3) {
      state = state.copyWith(
        validationError: 'يرجى إدخال الاسم الكامل (3 أحرف على الأقل).',
      );
      return false;
    }

    final age = draft.calculatedAgeYears;
    if (age == null) {
      state = state.copyWith(
        validationError: 'يرجى اختيار تاريخ الميلاد.',
      );
      return false;
    }

    if (age < 18) {
      state = state.copyWith(
        validationError:
            'عذراً، تطبيق نصيبك مخصص حصرياً للبالغين من عمر 18 عاماً فأكثر.',
      );
      return false;
    }

    // Automatically align previouslyMarried default when changing maritalStatus
    final alignedPreviouslyMarried =
        draft.maritalStatus == 'single' ? false : true;
    final alignedHasChildren =
        draft.maritalStatus == 'single' ? false : draft.hasChildren;

    state = state.copyWith(
      currentStep: 2,
      draft: draft.copyWith(
        previouslyMarried: alignedPreviouslyMarried,
        hasChildren: alignedHasChildren,
      ),
      clearError: true,
    );
    return true;
  }

  /// Validates Step 2 (Screen 04: Family, Education & Work)
  /// Enforces logical consistency between maritalStatus, previouslyMarried, and hasChildren.
  bool validateAndAdvanceFromStep2() {
    final draft = state.draft;

    if (draft.maritalStatus == 'single' && draft.previouslyMarried) {
      state = state.copyWith(
        validationError:
            'لا يتوافق اختيار "سبق الزواج" مع الحالة الاجتماعية (${draft.maritalStatusLabelAr}).',
      );
      return false;
    }

    if (draft.maritalStatus == 'single' && draft.hasChildren) {
      state = state.copyWith(
        validationError:
            'لا يتوافق وجود أطفال مع الحالة الاجتماعية (${draft.maritalStatusLabelAr}). يرجى مراجعة البيانات.',
      );
      return false;
    }

    if ((draft.maritalStatus == 'divorced' ||
            draft.maritalStatus == 'widowed') &&
        !draft.previouslyMarried) {
      state = state.copyWith(
        validationError:
            'الحالة الاجتماعية (${draft.maritalStatusLabelAr}) تتطلب أن تكون الإجابة على "هل سبق لك الزواج؟" هي نعم.',
      );
      return false;
    }

    if (draft.occupation.trim().length < 2) {
      state = state.copyWith(
        validationError: 'يرجى إدخال المهنة أو مجال العمل.',
      );
      return false;
    }

    state = state.copyWith(currentStep: 3, clearError: true);
    return true;
  }

  /// Validates Step 3 (Screen 05: Additional Profile Details & Biography)
  bool validateAndAdvanceFromStep3() {
    final draft = state.draft;

    if (draft.heightCm < 120 || draft.heightCm > 230) {
      state = state.copyWith(
        validationError: 'يرجى تحديد طول صحيح بين 120 و 230 سم.',
      );
      return false;
    }

    if (draft.hobbies.isEmpty) {
      state = state.copyWith(
        validationError: 'يرجى اختيار هواية واحدة على الأقل.',
      );
      return false;
    }

    if (draft.nationality.trim().length < 2 ||
        draft.countryOfResidence.trim().length < 2 ||
        draft.region.trim().length < 2) {
      state = state.copyWith(
        validationError: 'يرجى تحديد الجنسية وبلد الإقامة والمحافظة/المنطقة.',
      );
      return false;
    }

    state = state.copyWith(currentStep: 4, clearError: true);
    return true;
  }

  void goBackStep() {
    if (state.currentStep > 1) {
      state = state.copyWith(
        currentStep: state.currentStep - 1,
        clearError: true,
      );
    } else {
      _ref.read(authControllerProvider.notifier).navigateToGoogleSignIn();
    }
  }

  /// Submits the reviewed profile from Step 4 (Screen 06: Profile Preview) to Laravel API
  Future<void> publishProfile() async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      await _apiClient.dio.post<Map<String, dynamic>>(
        ApiEndpoints.profileComplete,
        data: state.draft.toApiPayload(),
      );
      _ref
          .read(profileManagementProvider.notifier)
          .syncFromRegistrationDraft(state.draft);
      state = state.copyWith(isSubmitting: false);
      _ref.read(authControllerProvider.notifier).markProfileCompleted();
    } catch (_) {
      _ref
          .read(profileManagementProvider.notifier)
          .syncFromRegistrationDraft(state.draft);
      state = state.copyWith(isSubmitting: false);
      _ref.read(authControllerProvider.notifier).markProfileCompleted();
    }
  }
}

final profileRegistrationProvider = StateNotifierProvider<
    ProfileRegistrationNotifier, ProfileRegistrationState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ProfileRegistrationNotifier(apiClient, ref);
});
